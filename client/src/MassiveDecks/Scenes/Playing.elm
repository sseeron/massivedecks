module MassiveDecks.Scenes.Playing exposing (update, view, init, subscriptions)

import Random
import String

import Html exposing (..)
import Html.App as Html
import Html.Attributes as Html

import AnimationFrame

import MassiveDecks.API as API
import MassiveDecks.API.Request as Request
import MassiveDecks.Models exposing (Init)
import MassiveDecks.Components.Errors as Errors
import MassiveDecks.Models.Card as Card
import MassiveDecks.Models.Game as Game
import MassiveDecks.Scenes.Lobby.Models as Lobby
import MassiveDecks.Scenes.Playing.UI as UI
import MassiveDecks.Scenes.Playing.Models exposing (Model, ShownPlayedCards)
import MassiveDecks.Scenes.Playing.Messages exposing (ConsumerMessage(..), Message(..))
import MassiveDecks.Scenes.Playing.HouseRule as HouseRule exposing (HouseRule)
import MassiveDecks.Scenes.Playing.HouseRule.Id as HouseRule
import MassiveDecks.Scenes.Playing.HouseRule.Reboot as Reboot
import MassiveDecks.Util as Util exposing ((:>))


{-| Create the initial model for the playing scene.
-}
init : Init -> Model
init init =
  { picked = []
  , considering = Nothing
  , finishedRound = Nothing
  , shownPlayed = { animated = [], toAnimate = [] }
  , seed = Random.initialSeed (hack init.seed)
  }


houseRule : HouseRule.Id -> HouseRule
houseRule id =
  case id of
    HouseRule.Reboot -> Reboot.rule


{-| We shouldn't need to do this!
int flags blow up at the moment. For now, we pass a string, but we should take an int from JS in the future.
-}
hack : String -> Int
hack seed = String.toInt seed |> Result.withDefault 0


{-| Subscriptions for the playing scene.
-}
subscriptions : Model -> Sub ConsumerMessage
subscriptions model = AnimationFrame.diffs (\_ -> LocalMessage CheckForPlayedCardsToAnimate)


{-| Render the playing scene.
-}
view : Lobby.Model -> (List (Html ConsumerMessage), List (Html ConsumerMessage))
view model =
  let
    (header, content) = UI.view model
  in
    (header |> List.map (Html.map LocalMessage), content |> List.map (Html.map LocalMessage))


{-| Handles messages and alters the model as appropriate.
-}
update : Message -> Lobby.Model -> (Model, Cmd ConsumerMessage)
update message lobbyModel =
  let
    model = lobbyModel.playing
    lobby = lobbyModel.lobby
    secret = lobbyModel.secret
    gameCode = lobby.gameCode
  in
    case message of
      Pick cardId ->
        let
          slots = Maybe.withDefault 0 (Maybe.map (\round -> Card.slots round.call) lobby.round)
          canPlay = (List.length model.picked) < slots
          playing = Maybe.withDefault False (Maybe.map (\round -> case round.responses of
            Card.Revealed _ -> False
            Card.Hidden _ -> True
          ) lobby.round)
        in
          if playing && canPlay then
            ({ model | picked = model.picked ++ [ cardId ] }, Cmd.none)
          else
            (model, Cmd.none)

      Withdraw cardId ->
        ({ model | picked = List.filter ((/=) cardId) model.picked }, Cmd.none)

      Play ->
        ( { model | picked = [] }
        , Request.send (API.play gameCode secret model.picked) playErrorHandler ErrorMessage (UpdateLobbyAndHand >> LocalMessage)
        )

      Consider potentialWinnerIndex ->
        ( { model | considering = Just potentialWinnerIndex }
        , Cmd.none
        )

      Choose winnerIndex ->
        ( { model | considering = Nothing }
        , Request.send (API.choose gameCode secret winnerIndex) chooseErrorHandler ErrorMessage (UpdateLobbyAndHand >> LocalMessage)
        )

      NextRound ->
        ( { model | considering = Nothing
                  , finishedRound = Nothing
          }
        , Cmd.none
        )

      CheckForPlayedCardsToAnimate ->
        ( model
        , if List.isEmpty model.shownPlayed.toAnimate then Cmd.none else Util.cmd (LocalMessage AnimatePlayedCards)
        )

      AnimatePlayedCards ->
        let
          _ = Debug.log "Animating played cards!" model.shownPlayed
          (shownPlayed, seed) = updatePositioning model.shownPlayed model.seed
        in
          ( { model | seed = seed
                    , shownPlayed = shownPlayed
                    }
          , Cmd.none
          )

      Skip playerIds ->
        (model, Request.send (API.skip gameCode secret playerIds) skipErrorHandler ErrorMessage (UpdateLobbyAndHand >> LocalMessage))

      Back ->
        (model, Request.send' (API.back gameCode secret) ErrorMessage (UpdateLobbyAndHand >> LocalMessage))

      UpdateLobbyAndHand lobbyAndHand ->
        updateLobbyAndHand lobbyAndHand lobbyModel

      Redraw ->
        (model, Request.send (API.redraw lobbyModel.lobby.gameCode lobbyModel.secret) redrawErrorHandler ErrorMessage (UpdateLobbyAndHand >> LocalMessage))

      NoOp ->
        (model, Cmd.none)


updateLobbyAndHand : Game.LobbyAndHand -> Lobby.Model -> (Model, Cmd ConsumerMessage)
updateLobbyAndHand lobbyAndHand lobbyModel =
  let
    lobby = lobbyAndHand.lobby
    model = lobbyModel.playing
    shownPlayed = model.shownPlayed
    playedCards = lobby.round `Maybe.andThen` (\round ->
      case round.responses of
        Card.Hidden count -> Just count
        Card.Revealed _ -> Nothing)
    (newShownPlayed, seed) = case playedCards of
      Just amount ->
        let
          existing = (List.length shownPlayed.animated) + (List.length shownPlayed.toAnimate)
          (new, seed) = addShownPlayed (amount - existing) model.seed
        in
          (ShownPlayedCards shownPlayed.animated (shownPlayed.toAnimate ++ new), seed)

      Nothing ->
        (ShownPlayedCards [] [], model.seed)

    newModel = { model | shownPlayed = newShownPlayed
                       , seed = seed}
  in
    (newModel, Util.cmd (LobbyUpdate lobbyAndHand))


redrawErrorHandler : API.RedrawError -> ConsumerMessage
redrawErrorHandler error =
  case error of
    API.NotEnoughPoints -> ErrorMessage <| Errors.New "You do not have enough points to redraw your hand." False


chooseErrorHandler : API.ChooseError -> ConsumerMessage
chooseErrorHandler error =
  case error of
    API.NotCzar -> ErrorMessage <| Errors.New "You can't pick a winner as you are not the card czar this round." False


playErrorHandler : API.PlayError -> ConsumerMessage
playErrorHandler error =
  case error of
    API.NotInRound ->
      ErrorMessage <| Errors.New "You can't play as you are not in this round." False

    API.AlreadyPlayed ->
      ErrorMessage <| Errors.New "You can't play as you have already played in this round." False

    API.AlreadyJudging ->
      ErrorMessage <| Errors.New "You can't play as the round is already in it's judging phase." False

    API.WrongNumberOfCards got expected ->
      ErrorMessage <| Errors.New ("You played the wrong number of cards - you played " ++ (toString got) ++ " cards, but the call needs " ++ (toString expected) ++ "cards.") False


skipErrorHandler : API.SkipError -> ConsumerMessage
skipErrorHandler error =
  case error of
    API.NotEnoughPlayersToSkip ->
      ErrorMessage <| Errors.New "There are not enough players in the game to skip." False

    API.PlayersNotSkippable ->
      ErrorMessage <| Errors.New "The players can't be skipped as they are not inactive." False


addShownPlayed : Int -> Random.Seed -> (List (Html.Attribute msg), Random.Seed)
addShownPlayed new seed = Random.step (Random.list new initialRandomPositioning) seed


updatePositioning : ShownPlayedCards -> Random.Seed -> (ShownPlayedCards, Random.Seed)
updatePositioning shownPlayed seed =
  let
    (newAnimated, newSeed) = Random.step (Random.list (List.length shownPlayed.toAnimate) randomPositioning) seed
  in
    (ShownPlayedCards (shownPlayed.animated ++ newAnimated) [], newSeed)


randomPositioning : Random.Generator (Html.Attribute msg)
randomPositioning = Random.map4 positioning (Random.int -75 75) (Random.int 0 50) Random.bool (Random.int -5 1)


initialRandomPositioning : Random.Generator (Html.Attribute msg)
initialRandomPositioning = Random.map3 (\r h l -> positioning r h l -100) (Random.int -75 75) (Random.int 0 50) Random.bool


positioning : Int -> Int -> Bool -> Int -> Html.Attribute msg
positioning rotation horizontalPos left verticalPos =
  let
    horizontalDirection = if left then "left" else "right"
  in
    Html.style
      [ ("transform", "rotate(" ++ (toString rotation) ++ "deg)")
      , (horizontalDirection, (toString horizontalPos) ++ "%")
      , ("top", (toString verticalPos) ++ "%")
      ]