{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module OpenItemCount where

import Clay.Background
import Clay.Display
import Clay.Font
import Clay.Text
import Control.Lens ((.=))
import Francium
import Francium.Component
import Francium.HTML
import Prelude hiding (span)
import ToDoItem (Status(..))
import VirtualDom
import VirtualDom.Prim

data OpenItemCount t =
  OpenItemCount {items :: Behavior t [Status]}

instance Component OpenItemCount where
  data Output behavior event OpenItemCount = OpenItemCountOutput
  construct oic =
    do let openItemCount =
             fmap (length .
                   filter (== Incomplete))
                  (items oic)
       return Instantiation {outputs = OpenItemCountOutput
                            ,render =
                               fmap (\n ->
                                       with span_
                                            (style .=
                                             (do textAlign (alignSide sideLeft)
                                                 float floatLeft))
                                            [with strong_
                                                  (style .=
                                                   fontWeight (weight 300))
                                                  [text (show n)]
                                            ," "
                                            ,if n == 1
                                                then "item"
                                                else "items"
                                            ," left"])
                                    openItemCount}
