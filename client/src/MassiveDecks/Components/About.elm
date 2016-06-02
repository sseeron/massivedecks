module MassiveDecks.Components.About exposing (show)

import Html exposing (..)
import Html.Attributes exposing (..)

import MassiveDecks.Components.Overlay as Overlay


show : Overlay.Message a
show = Overlay.Show icon title contents


icon : String
icon = "info-circle"


title : String
title = "About"


contents : List (Html a)
contents =
  [ p [] [ text "Massive Decks is a web game based on the excellent "
         , a [ href "https://cardsagainsthumanity.com/", target "_blank" ] [ text "Cards against Humanity" ]
         , text " - a party game where you play white cards to try and produce the most amusing outcome when "
         , text "combined with the given black card."
         ]
  , p [] [ text "Massive Decks is also inspired by: "
         , ul [] [ li [] [ a [ href "https://www.cardcastgame.com/", target "_blank" ] [ text "Cardcast" ]
                         , text " - an app that allows you to play on a ChromeCast."
                         ]
                 , li [] [ a [ href "http://pretendyoure.xyz/zy/", target "_blank" ] [ text "Pretend You're Xyzzy" ]
                         , text " - a web game where you can jump in with people you don't know."
                         ]
                 ]
         ]
  , p [] [ text "This is an open source game developed in "
         , a [ href "http://elm-lang.org/", target "_blank" ] [ text "Elm" ]
         , text " for the client and "
         , a [ href "http://www.scala-lang.org/", target "_blank" ] [ text "Scala" ]
         , text " for the server."
         ]
  , p [] [ text "We also use: "
         , ul [] [ li [] [ a [ href "https://www.cardcastgame.com/", target "_blank" ] [ text "Cardcast" ]
                         , text "'s APIs for getting decks of cards (you can go there to make your own!)."
                         ]
                 , li [] [ text "The "
                         , a [ href "https://www.playframework.com/", target "_blank" ] [ text "Play framework" ]
                         ]
                 , li [] [ a [ href "http://lesscss.org/", target "_blank" ] [ text "Less" ] ]
                 , li [] [ a [ href "https://fortawesome.github.io/Font-Awesome/", target "_blank" ] [ text "Font Awesome" ] ]
                 , li [] [ a [ href "https://www.muicss.com", target "_blank" ] [ text "MUI" ] ]
                 ]
         ]
  , p [] [ text "Bug reports and contributions are welcome on the "
         , a [ href "https://github.com/Lattyware/massivedecks", target "_blank" ] [ text "GitHub repository" ]
         , text ", where you can find the complete source to the game, under the GPLv3 license. The game concept "
         , text "'Cards against Humanity' is used under a "
         , a [ href "https://creativecommons.org/licenses/by-nc-sa/2.0/", target "_blank" ] [ text "Creative Commons BY-NC-SA 2.0 license" ]
         , text " granted by "
         , a [ href "https://cardsagainsthumanity.com/", target "_blank" ] [ text "Cards against Humanity" ]
         ]
  ]
