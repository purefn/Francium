{-# LANGUAGE OverloadedStrings #-}

import Control.Arrow
import Francium
import Francium.HTML hiding (map)
import Control.Monad
import qualified Francium.HTML as HTML
import Control.Lens ((?=), at)
import Prelude hiding (div, span)
import Reactive.Banana
import GHCJS.Foreign
import GHCJS.Types
import Francium.Component

import ClearCompleted
import NewItemAdder
import ToDoItem
import StateFilter

main :: IO ()
main =
  react (do itemAdder <- construct NewItemAdder
            stateFilter <- construct StateFilter
            clearCompleted <-
              construct ClearCompleted
            eAddItem <-
              execute (fmap (\x ->
                               FrameworksMoment
                                 (trimComponent =<<
                                  construct (ToDoItem x)))
                            (filterE (not . isEmptyString . fromJSString)
                                     (addItem (outputs itemAdder))))
            let eItemsChanged =
                  accumE []
                         (unions [fmap append eAddItem
                                 ,destroy
                                 ,fmap const
                                       (incompleteItems <@
                                        ClearCompleted.clearCompleted (outputs clearCompleted))])
                incompleteItems =
                  fmap (map snd .
                        filter ((== Incomplete) . fst))
                       (switchB (pure [])
                                (fmap (traverse (\item ->
                                                   fmap (id &&& const item)
                                                        (status (outputs item))))
                                      eItemsChanged))
                openItemCount =
                  fmap (length .
                        filter (== Incomplete) .
                        map snd)
                       items
                items =
                  let switchField f =
                        switchB (pure [])
                                (fmap (sequenceA . fmap f) eItemsChanged)
                  in zipWith (,) <$>
                     switchField render <*>
                     switchField (status . outputs)
                destroy =
                  switchE (fmap (\events ->
                                   anyMoment (fmap (unions .
                                                    (zipWith (\i -> (deleteElem i <$))
                                                             [0 ..]))
                                                   (mapM now events)))
                                (fmap (map (ToDoItem.destroy . outputs)) eItemsChanged))
                visibleItems =
                  liftA2 (\f ->
                            map fst .
                            (filter (f . snd)))
                         (stateFilterF (outputs stateFilter))
                         items
            return (fmap appView
                         (TodoApp <$> render itemAdder <*> visibleItems <*>
                          openItemCount <*> render stateFilter <*>
                          fmap void items <*>
                          render clearCompleted)))
  where append x xs =
          xs ++
          [x]
        isEmptyString x =
          null (fromJSString x :: String)

deleteElem :: Int -> [a] -> [a]
deleteElem i [] = []
deleteElem i (x:xs)
  | i < 0 = xs
  | i > length xs = xs
  | i == 0 = xs
  | otherwise = x : deleteElem (i - 1) xs

mainContainer :: HTML
mainContainer =
  with div
       (attrs .
        at "style" ?=
        "padding: 0px; margin: 0px auto; font-weight: 300; -webkit-font-smoothing: antialiased; max-width: 550px; min-width: 230px; color: rgb(77, 77, 77); line-height: 1.4em; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 14px; font-stretch: normal; font-variant: normal; font-style: normal; background-color: rgb(245, 245, 245);")
       []

pageTitle :: HTML
pageTitle =
  with h1
       (do attrs .
             at "style" ?=
             "text-rendering: optimizelegibility; color: rgba(175, 47, 47, 0.14902); text-align: center; font-weight: 100; font-size: 100px; width: 100%; top: -155px; position: absolute;")
       ["todos"]

toDoContainer :: HTML
toDoContainer =
  with ul
       (do attrs .
             at "style" ?=
             "list-style-type: none; padding: 0px; margin: 0px;")
       []

completeToDo :: HTML
completeToDo =
  with li
       (do attrs .
             at "style" ?=
             "border-bottom-color: rgb(237, 237, 237); border-bottom-style: solid; border-bottom-width: 1px; font-size: 24px; position: relative;")
       [into div
             [with input
                   (do attrs .
                         at "style" ?=
                         "outline-style: none; -webkit-appearance: none; border-style: none; margin: auto 0px; bottom: 0px; top: 0px; position: absolute; height: 40px; width: 40px; text-align: center; background-image: none;"
                       attrs .
                         at "type" ?=
                         "checkbox"
                       attrs .
                         at "checked" ?=
                         "")
                   []
             ,with label
                   (do attrs .
                         at "style" ?=
                         "-webkit-transition: color 0.4s initial initial; transition: color 0.4s initial initial; line-height: 1.2; display: block; margin-left: 45px; padding: 15px 60px 15px 15px; word-break: break-word; white-space: pre; text-decoration-line: line-through; color: rgb(217, 217, 217);")
                   ["Taste JavaScript"]
             ,with button
                   (do attrs .
                         at "style" ?=
                         "-webkit-font-smoothing: antialiased; -webkit-appearance: none; vertical-align: baseline; font-size: 30px; border-width: 0px; padding: 0px; margin: auto 0px 11px; outline-style: none; -webkit-transition: color 0.2s ease-out initial; transition: color 0.2s ease-out initial; color: rgb(204, 154, 154); height: 40px; width: 40px; bottom: 0px; right: 10px; top: 0px; position: absolute; display: none; background-image: none;")
                   []]]

toDoSummary :: Int -> HTML -> HTML -> HTML
toDoSummary n stateFilter clearCompleted =
  with footer
       (do attrs .
             at "style" ?=
             "border-top-color: rgb(230, 230, 230); border-top-style: solid; border-top-width: 1px; text-align: center; height: 20px; padding: 10px 15px; color: rgb(119, 119, 119);")
       [with div
             (attrs .
              at "style" ?=
              "content: ''; position: absolute; right: 0; bottom: 0; left: 0; height: 50px; overflow: hidden; box-shadow: 0 1px 1px rgba(0, 0, 0, 0.2), 0 8px 0 -3px #f6f6f6, 0 9px 1px -3px rgba(0, 0, 0, 0.2), 0 16px 0 -6px #f6f6f6, 0 17px 2px -6px rgba(0, 0, 0, 0.2);")
             []
       ,with span
             (do attrs .
                   at "style" ?=
                   "text-align: left; float: left;")
             [with strong
                   (do attrs .
                         at "style" ?=
                         "font-weight: 300;")
                   [text (show n)]
             ," "
             ,if n == 1
                 then "item"
                 else "items"
             ," left"]
       ,stateFilter
       ,clearCompleted
       ,with button
             (do attrs .
                   at "style" ?=
                   "-webkit-font-smoothing: antialiased; -webkit-appearance: none; vertical-align: baseline; font-size: 100%; border-width: 0px; padding: 0px; margin: 0px; outline-style: none; position: relative; visibility: hidden; cursor: pointer; text-decoration-line: none; line-height: 20px; float: right; background-image: none;")
             []]

pageFooter :: HTML
pageFooter =
  with footer
       (do attrs .
             at "style" ?=
             "text-align: center; text-shadow: rgba(255, 255, 255, 0.498039) 0px 1px 0px; font-size: 10px; color: rgb(191, 191, 191); margin: 65px auto 0px;")
       [with p
             (do attrs .
                   at "style" ?=
                   "line-height: 1;")
             ["Double-click to edit a todo"]
       ,with p
             (do attrs .
                   at "style" ?=
                   "line-height: 1;")
             ["Template by "
             ,with a
                   (do attrs .
                         at "style" ?=
                         "font-weight: 400; text-decoration-line: none;"
                       attrs .
                         at "href" ?=
                         "http://sindresorhus.com")
                   ["Sindre Sorhus"]]
       ,with p
             (do attrs .
                   at "style" ?=
                   "line-height: 1;")
             ["Created by "
             ,with a
                   (do attrs .
                         at "style" ?=
                         "font-weight: 400; text-decoration-line: none;"
                       attrs .
                         at "href" ?=
                         "http://todomvc.com")
                   ["you"]]
       ,with p
             (do attrs .
                   at "style" ?=
                   "line-height: 1;")
             ["Part of "
             ,with a
                   (do attrs .
                         at "style" ?=
                         "font-weight: 400; text-decoration-line: none;"
                       attrs .
                         at "href" ?=
                         "http://todomvc.com")
                   ["TodoMVC"]]]

data TodoApp =
  TodoApp {taAddANewItem :: HTML
          ,taItems :: [HTML]
          ,taOpenItemCount :: Int
          ,taStateFilter :: HTML
          ,taAllItems :: [()]
          ,taClearCompleted :: HTML}

appView :: TodoApp -> HTML
appView (TodoApp addANewItem items openItemCount stateFilter allItems clearCompleted) =
  into mainContainer
       [with section
             (attrs .
              at "style" ?=
              "box-shadow: rgba(0, 0, 0, 0.2) 0px 2px 4px 0px, rgba(0, 0, 0, 0.0980392) 0px 25px 50px 0px; position: relative; margin: 130px 0px 40px; background-color: rgb(255, 255, 255);")
             (into header [pageTitle,addANewItem] :
              case allItems of
                [] -> []
                _ ->
                  [with section
                        (do attrs .
                              at "style" ?=
                              "border-top-color: rgb(230, 230, 230); border-top-style: solid; border-top-width: 1px; z-index: 2; position: relative;")
                        [with input
                              (do attrs .
                                    at "style" ?=
                                    "outline-style: none; border-style: none; text-align: center; height: 34px; width: 60px; left: -12px; top: -55px; position: absolute; -webkit-appearance: none; transform: rotate(90deg); -webkit-transform: rotate(90deg); background-image: none;"
                                  attrs .
                                    at "type" ?=
                                    "checkbox")
                              []
                        ,with label
                              (do attrs .
                                    at "style" ?=
                                    "display: none;"
                                  attrs .
                                    at "for" ?=
                                    "toggle-all")
                              ["Mark all as complete"]
                        ,into toDoContainer (map (into itemContainer . pure) items)]
                  ,toDoSummary openItemCount stateFilter clearCompleted])
       ,pageFooter
       ,with div
             (do attrs .
                   at "style" ?=
                   "z-index: 2147483646; width: auto; white-space: normal; vertical-align: baseline; top: auto; text-transform: none; text-shadow: rgb(255, 255, 255) 0px 1px 2px; text-indent: 0px; text-decoration-line: none; text-align: left; right: 150px; position: fixed; padding: 3px 3px 2px; opacity: 0; min-width: 150px; min-height: 13px; max-width: 400px; max-height: none; margin: 0px; line-height: 1; letter-spacing: 0px; left: auto; height: 13px; font-weight: normal; font-variant: normal; font-style: normal; font-family: 'Lucida Grande', Arial, Sans; float: none; display: none; cursor: auto; color: black; box-shadow: none; bottom: 0px; border: 1px solid rgb(179, 179, 179); font-size: 12px; border-radius: 4px 4px 0px 0px; background-image: none; background-color: rgb(235, 235, 235);")
             []]
  where itemContainer =
          with li
               (attrs .
                at "style" ?=
                "border-bottom-color: rgb(237, 237, 237); border-bottom-style: none; border-bottom-width: 1px; font-size: 24px; position: relative;")
               []
