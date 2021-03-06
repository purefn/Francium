{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecursiveDo #-}
{-# LANGUAGE TypeFamilies #-}

module NewItemAdder (NewItemAdder(..), addItem) where

import Control.Lens ((?=), (.=))
import Francium
import Francium.CSS
import Francium.Component
import Francium.HTML
import Francium.Hooks
import GHCJS.Types
import Prelude hiding (div, span)
import TextInput

-- | The 'NewItemAdder' component allows users to add new items to their to-do
-- list. Visually, it appears as an <input> box, and fires the 'addItem' event
-- when the user presses the return key on their keyboard.
data NewItemAdder t =
  NewItemAdder

instance Component NewItemAdder where
  data Output behavior event NewItemAdder = NewItemOutput{addItem ::
                                                        event JSString}
  construct NewItemAdder =
    mdo
        -- Construct an input field component.
        inputComponent <-
          construct (TextInput {initialText = ""
                               ,updateText =
                                  fmap (const (const "")) returnPressed})
        -- We add a new "hook" to the event network to observe whenever the user
        -- presses a key. Later, we will filter this event stream to only fire
        -- when return is pressed.
        (hookKeyPress,keyPressed) <- newKeyPressHook
        let
            -- The keyPressed event gives us an event whenever a key is pressed.
            -- We only need to know when the user presses return, so we filter
            -- the event stream accordingly.
            returnPressed = listenForReturn keyPressed
            -- The itemValue is the title of the to-do item being added. We
            -- pass through the behavior from the TextInput component, which
            -- provides us with the contents of the text box.
            itemValue =
              TextInput.value (outputs inputComponent)
        reactimate (fmap print keyPressed)
        return Instantiation {render =
                                -- To render the component, we simply reskin the
                                -- TextInput component
                                fmap
                                  (applyHooks hookKeyPress .
                                   modifyElement inputAttributes)
                                  (render inputComponent)
                             ,outputs =
                                -- The outputs of this component is an Event
                                -- that samples the contents of the input field
                                -- whenever return is pressed.
                                NewItemOutput {addItem = itemValue <@
                                                         returnPressed}}
    where inputAttributes =
            do style .=
                 (do boxSizing borderBox
                     insetBoxShadow inset
                                    (px 0)
                                    (px (-2))
                                    (px 1)
                                    (rgba 0 0 0 7)
                     borderStyle none
                     padding (px 15)
                             (px 15)
                             (px 15)
                             (px 60)
                     outlineStyle none
                     lineHeight (em 1.5)
                     fontSize (px 24)
                     width (pct 100)
                     sym margin (px 0)
                     position relative
                     backgroundColor (rgba 0 0 0 0))
               placeholder_ ?= "What needs to be done?"
               autofocus_ ?= ""

listenForReturn :: (Num a, Eq a) => Event t a -> Event t a
listenForReturn = filterE (== returnKeyCode)
  where returnKeyCode = 13
