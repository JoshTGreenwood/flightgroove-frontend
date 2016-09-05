module UIComponents.Filters.Location
    exposing
        ( Model
        , Msg
        , model
        , update
        , view
        , subscriptions
        , getSelectedLocation
        )

-- Core Imports

import Html exposing (..)
import Html.App
import Html.Attributes exposing (class)
import Http
import Task
import String


-- THird party packages

import Material exposing (..)
import Material.Textfield as Textfield
import Autocomplete


-- Custom Modules

import API.Response as Response
import API.Skyscanner as API


type alias Model =
    { mdl : Material.Model
    , autocompleteState : Autocomplete.State
    , chosenLocationId : String
    , displayText : String
    , locationList : Response.Locations
    , maxLocationsDisplayed : Int
    , showLocationsDropdown : Bool
    }


type Msg
    = InputQuery String
    | SelectLocation String
    | FetchSuccess Response.Response
    | FetchFail Http.Error
    | AutocompleteMsg Autocomplete.Msg
    | Mdl (Material.Msg Msg)


model : Model
model =
    { mdl = Material.model
    , autocompleteState = Autocomplete.empty
    , chosenLocationId = ""
    , displayText = ""
    , locationList = []
    , maxLocationsDisplayed = 10
    , showLocationsDropdown = False
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- MDL Boilerplate
        Mdl msg' ->
            Material.update msg' model

        InputQuery txt ->
            if String.isEmpty txt then
                ( { model | displayText = txt, showLocationsDropdown = False, locationList = [] }, Cmd.none )
            else
                ( { model | displayText = txt, showLocationsDropdown = True }, updateAirportList txt )

        SelectLocation locationId ->
            ( { model
                | chosenLocationId = locationId
                , showLocationsDropdown = False
                , displayText = formattedLocationNameFromId model.locationList locationId
              }
            , Cmd.none
            )

        FetchSuccess response ->
            case response of
                Response.LocationsResponse locations ->
                    ( { model | locationList = locations }, Cmd.none )

                Response.RoutesResponse routes ->
                    model ! []

        FetchFail error ->
            model ! []

        AutocompleteMsg msg ->
            updateAutocomplete msg model


getSelectedLocation : Model -> String
getSelectedLocation model =
    model.chosenLocationId


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map AutocompleteMsg Autocomplete.subscription


view : Model -> Html Msg
view model =
    div [ class "dropdown-container" ]
        [ viewAirportSelector model
        , viewAutocomplete model
        ]



-- Unexposed Functions


updateAutocomplete : Autocomplete.Msg -> Model -> ( Model, Cmd Msg )
updateAutocomplete msg model =
    let
        ( newAutoState, maybeMsg ) =
            Autocomplete.update updateConfig msg model.autocompleteState model.locationList model.maxLocationsDisplayed

        newModel =
            { model | autocompleteState = newAutoState }
    in
        case maybeMsg of
            Nothing ->
                newModel ! []

            Just outMsg ->
                update outMsg newModel


updateAirportList : String -> Cmd Msg
updateAirportList query =
    Task.perform FetchFail FetchSuccess <|
        API.callLocations { query = query }


formattedLocationNameFromId : Response.Locations -> String -> String
formattedLocationNameFromId airportList chosenId =
    let
        chosenLocation =
            List.filter (\n -> n.placeId == chosenId) airportList
                |> List.head
    in
        case chosenLocation of
            Nothing ->
                "not found - "

            Just chosenLocation ->
                formatLocationName chosenLocation


formatLocationName : Response.LocationSuggestion -> String
formatLocationName location =
    location.placeName
        ++ ", "
        ++ location.countryName
        ++ " ("
        ++ location.placeId
        ++ ")"


viewAirportSelector : Model -> Html Msg
viewAirportSelector model =
    div []
        [ Textfield.render Mdl
            [ 8 ]
            model.mdl
            [ Textfield.label
                "Airport"
            , Textfield.onInput InputQuery
            , Textfield.autofocus
            , Textfield.floatingLabel
            , Textfield.value model.displayText
            ]
        ]


viewAutocomplete : Model -> Html Msg
viewAutocomplete model =
    let
        filteredList =
            filterLocations model.chosenLocationId model.locationList
    in
        if model.showLocationsDropdown then
            Html.App.map AutocompleteMsg <|
                Autocomplete.view viewConfig model.maxLocationsDisplayed model.autocompleteState filteredList
        else
            div [] []


filterLocations : String -> Response.Locations -> Response.Locations
filterLocations query locations =
    let
        transformedQuery =
            String.toLower query

        filterFunction =
            matchesLocation transformedQuery
    in
        List.filter filterFunction locations


matchesLocation : String -> Response.LocationSuggestion -> Bool
matchesLocation lowercaseQuery location =
    String.toLower location.placeName
        |> String.contains lowercaseQuery


updateConfig : Autocomplete.UpdateConfig Msg Response.LocationSuggestion
updateConfig =
    Autocomplete.updateConfig
        { onKeyDown =
            \code maybeId ->
                if code == 38 || code == 40 then
                    Nothing
                else if code == 13 then
                    Maybe.map SelectLocation maybeId
                else
                    Nothing
        , onTooLow = Nothing
        , onTooHigh = Nothing
        , onMouseEnter = \_ -> Nothing
        , onMouseLeave = \_ -> Nothing
        , onMouseClick = \id -> Just <| SelectLocation id
        , toId = .placeId
        , separateSelections = True
        }


viewConfig : Autocomplete.ViewConfig Response.LocationSuggestion
viewConfig =
    Autocomplete.viewConfig
        { toId = \airport -> airport.placeId
        , ul = [ class "autocomplete-list" ]
        , li = listItem
        }


listItem :
    Autocomplete.KeySelected
    -> Autocomplete.MouseSelected
    -> Response.LocationSuggestion
    -> Autocomplete.HtmlDetails Never
listItem keySelected mouseSelected location =
    if keySelected then
        { attributes = [ class "autocomplete-item autocomplete-item--key" ]
        , children = [ Html.text <| formatLocationName location ]
        }
    else if mouseSelected then
        { attributes = [ class "autocomplete-item autocomplete-item--mouse" ]
        , children = [ Html.text <| formatLocationName location ]
        }
    else
        { attributes = [ class "autocomplete-item" ]
        , children = [ Html.text <| formatLocationName location ]
        }
