module Main exposing (..)

import DOM exposing (..)
import Dom
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (style)
import Html.CssHelpers
import Html.Events exposing (onClick)
import Json.Decode exposing (Decoder)
import Json.Encode as Encode
import Mouse
import Process
import SelectCss
import String
import Task
import Time
import Dom.Scroll


--


itemHeight =
    32


menuHeight =
    200


fst =
    Tuple.first


snd =
    Tuple.second



--


main =
    Html.programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Flags =
    {}


values : List ( String, String )
values =
    [ ( "elixir-estonia", "ELIXIR Estonia" )
    , ( "unitartu", "University of Tartu" )
    , ( "cs", "Institute of Computer Science" )
    , ( "biit", "BIIT" )
    , ( "javascript", "JavaScript" )
    , ( "elm", "Elm" )
    , ( "haskell", "Haskell" )
    , ( "hask1ell", "Haskrell" )
    , ( "has2kell", "Haskrelel" )
    , ( "has3kell", "Haswkell" )
    , ( "has4kell", "Hasekell" )
    ]


type Status
    = Closed
    | Focused
    | Opened
    | Disabled


invisibleCharacter =
    "\x200C\x200C"


type alias Model =
    { status : Status
    , values : List ( String, String )
    , filtered : List ( String, String )
    , selected : List ( String, String )
    , protected : Bool
    , error : Maybe String
    , input : String
    , inputWidth : Float
    , hovered : Maybe ( String, String )
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Model
        Closed
        values
        (sortValues values)
        []
        False
        Nothing
        ""
        23.0
        (List.head (sortValues values))
    , Cmd.none
    )


sortValues : List ( String, String ) -> List ( String, String )
sortValues =
    List.sortWith (\t1 t2 -> compare (fst t1) (fst t2))



-- UPDATE


type Msg
    = Start
    | Click Mouse.Position
    | ClickOnComponent
    | DisableProtection
    | Toggle
    | OnSelect ( String, String )
    | RemoveItem ( String, String )
    | Clear
    | FocusResult (Result Dom.Error ())
    | ScrollResult (Result Dom.Error ())
    | Filter String
    | Adjust Float
    | ClearInput
    | OnHover ( String, String )
    | Shortcut Int
    | ScrollY (Result Dom.Error Float)



--| OnUnhover ( String, String )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Start ->
            ( model, Cmd.none )

        Toggle ->
            if model.status == Opened then
                ({ model | status = Closed }
                    ! [ Dom.focus "multiselectInput" |> Task.attempt FocusResult
                      ]
                )
            else
                ({ model | status = Opened }
                    ! [ Dom.focus "multiselectInput" |> Task.attempt FocusResult
                      ]
                )

        Click _ ->
            if model.protected then
                ( { model | protected = False }, Cmd.none )
            else
                ( { model | status = Closed }, Cmd.none )

        DisableProtection ->
            ( { model | protected = False }, Cmd.none )

        ClickOnComponent ->
            if model.protected then
                ( model, Cmd.none )
            else
                { model | status = Opened, protected = True }
                    ! [ Dom.focus "multiselectInput" |> Task.attempt FocusResult
                      , delay (Time.millisecond * 100) <| DisableProtection
                      ]

        ScrollResult result ->
            case result of
                Err (Dom.NotFound id) ->
                    { model | error = Just ("Could not find dom id: " ++ id) } ! []

                Ok () ->
                    if model.input == invisibleCharacter then
                        { model | input = "" } ! []
                    else
                        { model | error = Nothing } ! []

        FocusResult result ->
            case result of
                Err (Dom.NotFound id) ->
                    { model | error = Just ("Could not find dom id: " ++ id) } ! []

                Ok () ->
                    if model.input == invisibleCharacter then
                        { model | input = "" } ! []
                    else
                        { model | error = Nothing } ! []

        ClearInput ->
            { model | input = "" } ! []

        Adjust value ->
            { model | inputWidth = value } ! []

        Filter value ->
            let
                v =
                    List.filter (\v -> not (List.member v model.selected))
                        (List.filter (\( name, val ) -> String.contains (String.toLower value) (String.toLower val))
                            model.values
                        )
            in
                if model.protected then
                    ( { model | protected = False }, Cmd.none )
                else
                    case model.hovered of
                        Nothing ->
                            { model
                                | filtered = sortValues v
                                , input = value
                                , hovered = List.head (sortValues v)
                                , status =
                                    if List.isEmpty v then
                                        Closed
                                    else
                                        Opened
                            }
                                ! []

                        Just item ->
                            if List.length (List.filter (\i -> i == item) v) == 0 then
                                { model
                                    | filtered = sortValues v
                                    , input = value
                                    , hovered = List.head (sortValues v)
                                    , status =
                                        if List.isEmpty v then
                                            Closed
                                        else
                                            Opened
                                }
                                    ! []
                            else
                                { model
                                    | filtered = sortValues v
                                    , input = value

                                    --, hovered = List.head v
                                    , status =
                                        if List.isEmpty v then
                                            Closed
                                        else
                                            Opened
                                }
                                    ! []

        OnSelect item ->
            let
                v =
                    List.filter (\v -> not (List.member v model.selected))
                        (List.filter (\value -> value /= item) model.values)
            in
                { model
                    | selected = model.selected ++ [ item ]
                    , filtered = sortValues v
                    , hovered = nextSelectedItem model.filtered item
                    , input = invisibleCharacter
                    , status =
                        if List.isEmpty v then
                            Closed
                        else
                            Opened
                }
                    ! [ Dom.focus "multiselectInput" |> Task.attempt FocusResult
                      ]

        RemoveItem item ->
            ( { model
                | selected = List.filter (\value -> value /= item) model.selected
                , filtered = List.sortWith (\t1 t2 -> compare (fst t1) (fst t2)) (item :: model.filtered)
                , hovered = Just item
              }
            , Cmd.none
            )

        Clear ->
            { model
                | filtered = sortValues model.values
                , selected = []
                , input = invisibleCharacter
                , status = Closed
            }
                ! [ Dom.focus "multiselectInput" |> Task.attempt FocusResult
                  ]

        OnHover item ->
            { model | hovered = Just item } ! []

        ScrollY result ->
            case result of
                Err (Dom.NotFound id) ->
                    { model | error = Just ("Could not find dom id: " ++ id) } ! []

                Ok y ->
                    case model.hovered of
                        Nothing ->
                            model ! []

                        Just item ->
                            case indexOf item model.filtered of
                                Nothing ->
                                    model ! []

                                Just idx ->
                                    let
                                        boundaries =
                                            getBoundaries (toFloat idx)

                                        vpBoundaries =
                                            getViewPortBoundaries y

                                        scroll =
                                            fitViewPort boundaries vpBoundaries
                                    in
                                        { model | error = Nothing }
                                            ! [ Dom.Scroll.toY "multiselectMenu" scroll |> Task.attempt ScrollResult ]

        Shortcut key ->
            if key == 38 then
                case model.hovered of
                    Nothing ->
                        { model | hovered = List.head model.filtered } ! []

                    Just item ->
                        let
                            prev =
                                prevItem (sortValues model.filtered) item
                        in
                            { model | hovered = prev }
                                ! [ Dom.Scroll.y "multiselectMenu" |> Task.attempt ScrollY ]
            else if key == 40 then
                case model.hovered of
                    Nothing ->
                        { model | hovered = List.head model.filtered } ! []

                    Just item ->
                        let
                            next =
                                nextItem (sortValues model.filtered) item
                        in
                            { model | hovered = next }
                                ! [ Dom.Scroll.y "multiselectMenu" |> Task.attempt ScrollY ]
            else if key == 33 || key == 36 then
                let
                    first =
                        List.head (sortValues model.filtered)
                in
                    { model | hovered = first }
                        ! [ Dom.Scroll.y "multiselectMenu" |> Task.attempt ScrollY ]
            else if key == 34 || key == 35 then
                let
                    last =
                        lastElem (sortValues model.filtered)
                in
                    { model | hovered = last }
                        ! [ Dom.Scroll.y "multiselectMenu" |> Task.attempt ScrollY ]
            else if key == 13 then
                case model.hovered of
                    Nothing ->
                        model ! []

                    Just item ->
                        let
                            v =
                                List.filter (\v -> not (List.member v model.selected))
                                    (List.filter (\value -> value /= item) model.values)
                        in
                            { model
                                | selected = model.selected ++ [ item ]
                                , filtered = sortValues v
                                , hovered = nextSelectedItem model.filtered item
                                , input = invisibleCharacter
                                , status =
                                    if List.isEmpty v then
                                        Closed
                                    else
                                        Opened
                            }
                                ! [ Dom.focus "multiselectInput" |> Task.attempt FocusResult
                                  ]
            else if key == 27 then
                { model | status = Closed, protected = True } ! []
            else if key == 8 then
                if model.input == "" then
                    case lastElem model.selected of
                        Nothing ->
                            model ! []

                        Just item ->
                            { model
                                | selected = List.filter (\value -> value /= item) model.selected
                                , filtered = List.sortWith (\t1 t2 -> compare (fst t1) (fst t2)) (item :: model.filtered)
                                , hovered = Just item
                            }
                                ! []
                else
                    model ! []
            else
                model ! []


getViewPortBoundaries : Float -> ( Float, Float )
getViewPortBoundaries i =
    ( i, i + menuHeight )


getBoundaries : Float -> ( Float, Float )
getBoundaries i =
    ( (i * itemHeight), (i * itemHeight) + itemHeight )


fitViewPort : ( Float, Float ) -> ( Float, Float ) -> Float
fitViewPort ( top, bottom ) ( vpTop, vpBottom ) =
    if top < vpTop then
        top
    else if bottom > vpBottom then
        vpTop + (bottom - vpBottom)
    else
        vpTop



--OnUnhover item ->
--    case model.hovered of
--        Nothing ->
--            model ! []
--        Just item ->
--            if model.hovered == Just item then
--                { model | hovered = Nothing } ! []
--            else
--                model ! []


indexOf : a -> List a -> Maybe Int
indexOf el list =
    let
        helper l index =
            case l of
                [] ->
                    Nothing

                x :: xs ->
                    if x == el then
                        Just index
                    else
                        helper xs (index + 1)
    in
        helper list 0


lastElem : List a -> Maybe a
lastElem =
    List.foldl (Just >> always) Nothing


nextSelectedItem : List a -> a -> Maybe a
nextSelectedItem list item =
    let
        takeLast l =
            case l of
                [] ->
                    Nothing

                x :: [] ->
                    Nothing

                x :: y :: rest ->
                    Just y

        findNextInList l =
            case l of
                [] ->
                    Nothing

                x :: [] ->
                    if x == item then
                        takeLast (List.reverse list)
                    else
                        Nothing

                x :: y :: rest ->
                    if x == item then
                        Just y
                    else
                        findNextInList (y :: rest)
    in
        findNextInList list


nextItem : List a -> a -> Maybe a
nextItem list item =
    let
        findNextInList l =
            case l of
                [] ->
                    Nothing

                x :: [] ->
                    if x == item then
                        List.head list
                    else
                        Nothing

                x :: y :: rest ->
                    if x == item then
                        Just y
                    else
                        findNextInList (y :: rest)
    in
        findNextInList list


prevItem list item =
    nextItem (List.reverse list) item


delay : Time.Time -> msg -> Cmd msg
delay time msg =
    -- https://stackoverflow.com/questions/40599512/how-to-achieve-behavior-of-settimeout-in-elm
    Process.sleep time
        |> Task.perform (\_ -> msg)


fromResult : Result String a -> Decoder a
fromResult result =
    case result of
        Ok successValue ->
            Json.Decode.succeed successValue

        Err errorMessage ->
            Json.Decode.fail errorMessage



-- VIEW


infixr 5 :>
(:>) : (a -> b) -> a -> b
(:>) f x =
    f x


{ id, class, classList } =
    Html.CssHelpers.withNamespace "multiselect"


onClickNoDefault : msg -> Html.Attribute msg
onClickNoDefault message =
    let
        config =
            { stopPropagation = True
            , preventDefault = True
            }
    in
        Html.Events.onWithOptions "click" config (Json.Decode.succeed message)


view : Model -> Html Msg
view model =
    let
        inputClasses =
            if model.status == Focused then
                [ SelectCss.Container, SelectCss.Focused ]
            else if model.status == Opened then
                [ SelectCss.Container, SelectCss.Opened ]
            else
                [ SelectCss.Container ]
    in
        div
            [ class [ SelectCss.Wrap ]
            , onClick ClickOnComponent
            ]
            [ div
                [ class inputClasses
                ]
                [ tags model
                , input model
                , clear model
                , arrow model
                ]
            , menu model
            ]


send : msg -> Cmd msg
send msg =
    Task.succeed msg
        |> Task.perform identity


input : Model -> Html Msg
input model =
    let
        w =
            toString (model.inputWidth + 23.0)

        inputStyle =
            Html.Attributes.style [ ( "width", w ++ "px" ) ]

        value =
            if model.input == invisibleCharacter then
                Html.Attributes.property "value" (Encode.string model.input)
            else
                Html.Attributes.property "type" (Encode.string "text")
    in
        div
            [ preventDefaultButtons
            , class [ SelectCss.InputWrap ]
            ]
            [ div [ class [ SelectCss.InputMirrow ] ] [ text model.input ]
            , Html.input
                [ id "multiselectInput"
                , class [ SelectCss.Input ]
                , onKeyDown Adjust
                , onKeyPress Shortcut
                , onKeyUp Filter
                , inputStyle
                , value
                ]
                []
            ]


preventDefaultButtons : Html.Attribute Msg
preventDefaultButtons =
    let
        options =
            { preventDefault = True, stopPropagation = False }

        filterKey code =
            if code == 38 || code == 40 then
                Ok code
            else
                Err "ignored input"

        decoder =
            Html.Events.keyCode
                |> Json.Decode.andThen (filterKey >> fromResult)
                |> Json.Decode.map (always Start)
    in
        Html.Events.onWithOptions "keydown" options decoder


onKeyUp : (String -> msg) -> Html.Attribute msg
onKeyUp tagger =
    Html.Events.on "keyup" (Json.Decode.map tagger Html.Events.targetValue)


onKeyDown : (Float -> msg) -> Html.Attribute msg
onKeyDown tagger =
    Html.Events.on "keydown" (Json.Decode.map tagger (DOM.target :> DOM.previousSibling :> DOM.offsetWidth))


onKeyPress : (Int -> msg) -> Html.Attribute msg
onKeyPress tagger =
    Html.Events.on "keydown" (Json.Decode.map tagger Html.Events.keyCode)


tags : Model -> Html Msg
tags model =
    div [ class [ SelectCss.TagWrap ] ]
        (List.map
            (\( name, value ) ->
                tag name value
            )
            model.selected
        )


tag : String -> String -> Html Msg
tag name value =
    div [ class [ SelectCss.Tag ] ]
        [ Html.span
            [ class [ SelectCss.TagIcon ]
            , onClick (RemoveItem ( name, value ))
            ]
            [ text "×" ]
        , Html.span [ class [ SelectCss.TagLabel ] ] [ text value ]
        ]


arrow : Model -> Html Msg
arrow model =
    let
        arrowClasses =
            if model.status == Opened then
                [ SelectCss.ArrowUpside ]
            else
                [ SelectCss.Arrow ]
    in
        div
            [ class [ SelectCss.ArrowWrap ]
            , onClickNoDefault Toggle
            ]
            [ div [ class arrowClasses ] [] ]


clear : Model -> Html Msg
clear model =
    if not (List.isEmpty model.selected) then
        div
            [ class [ SelectCss.ClearWrap ]
            , onClickNoDefault Clear
            ]
            [ div [ class [ SelectCss.Clear ] ] [ text "×" ] ]
    else
        div [] []


menu : Model -> Html Msg
menu model =
    case model.status of
        Opened ->
            let
                hovered =
                    case model.hovered of
                        Nothing ->
                            ""

                        Just item ->
                            fst item
            in
                div [ class [ SelectCss.Menu ], id "multiselectMenu" ]
                    (List.map
                        (\( name, value ) ->
                            div
                                [ class
                                    (if name == hovered then
                                        [ SelectCss.MenuItemHovered, SelectCss.MenuItem ]
                                     else
                                        [ SelectCss.MenuItem ]
                                    )
                                , id
                                    (if name == hovered then
                                        "multiselectHovered"
                                     else
                                        ""
                                    )
                                , onClickNoDefault (OnSelect ( name, value ))
                                , Html.Events.onMouseOver (OnHover ( name, value ))

                                --, Html.Events.onMouseLeave (OnUnhover ( name, value ))
                                ]
                                [ text value ]
                        )
                        model.filtered
                    )

        _ ->
            div [] []



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.status == Opened then
        Mouse.clicks Click
    else
        Sub.none



-- OPERATIONS
-- HTTP