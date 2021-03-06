{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}

module Francium
  ( -- * Running Francium applications
    react
  , FranciumApp

    -- * Building HTML trees
  , with, into, text

    -- * Components
  , Component(..)
  , Instantiation(Instantiation)
  , render
  , outputs

    -- * Hooks
  , module Francium.Hooks

    -- * Routing
  , module Francium.Routing

    -- * 'reactive-banana' re-exports
    -- ** Core Combinators
  , Event
  , Behavior
  , union
  , unions
  , stepper
  , (<@>)
  , (<@)
  , accumB
  , accumE
  , initial
  , never
  , whenE
  , filterE
  , tag
  , constWhen
  , split
  , spill
  , filterJust

    -- ** Network Modifications
  , Moment
  , Frameworks
  , AddHandler(..)
  , fromAddHandler
  , reactimate
  , changes
  , reactimate'
  , FrameworksMoment(..)
  , execute
  , liftIO
  , liftIOLater
  , newEvent
  , Handler

    -- ** Switching Combinators
  , AnyMoment
  , anyMoment
  , now
  , switchB
  , switchE
  , trim

    -- *** Switching Components
  , trimComponent

    -- * Haskell browser functions
  , nextTick

    -- * Embedding 'IO'
  , ioAsEvent
  , ioAsEventLater

    -- * Re-exported modules
  , module Control.Applicative
  , lmap, dimap
  ) where

import Control.Applicative
import Control.Concurrent
import Control.Concurrent.STM
import Control.Monad ((<=<), forever)
import Control.Monad.IO.Class
import Data.Foldable
import Data.IORef
import Data.Profunctor
import Francium.Component
import Francium.HTML
import Francium.Hooks
import Francium.Routing
import GHCJS.Foreign
import GHCJS.Types
import Prelude hiding (div, mapM, sequence)
import Reactive.Banana
import Reactive.Banana.Frameworks
import VirtualDom
import qualified VirtualDom.Prim as VDom

--------------------------------------------------------------------------------
type FranciumApp = forall t. Frameworks t => Moment t (HTML (Behavior t))

react :: FranciumApp -> IO ()
react app =
  do container <- newTopLevelContainer
     _ <- initDomDelegator
     initialRender <-
       newIORef (VDom.emptyElement "div")
     renderChannel <- newTChanIO
     eventNetwork <-
       compile (do document <-
                     fmap (\x ->
                             case div_ x of
                               HTML beh ->
                                 fmap (head . toList) beh)
                          app
                   do html <- initial document
                      liftIOLater (atomically (writeTChan renderChannel html))
                   documentChanged <- changes document
                   reactimate'
                     (fmap (fmap (atomically . writeTChan renderChannel)) documentChanged))
     forkIO (forever (nextTick . renderTo container =<<
                      atomically (readTChan renderChannel)))
     actuate eventNetwork

--------------------------------------------------------------------------------
foreign import javascript unsafe
  "window.nextTick($1)"
  ffiNextTick :: JSFun (IO ()) -> IO ()

nextTick :: IO () -> IO ()
nextTick = ffiNextTick <=< syncCallback AlwaysRetain True

--------------------------------------------------------------------------------
-- | Immediately begin performing an 'IO' action asynchronously, and fire the
-- 'Event' once when it completes.
ioAsEvent :: Frameworks t => IO a -> Moment t (Event t a, ThreadId)
ioAsEvent io =
  do (ioComplete,fireIoComplete) <- newEvent
     thread <- liftIO (forkIO (io >>= fireIoComplete))
     return (ioComplete, thread)

-- | Build a deferred computation that when 'execute'd will perform the given
-- 'IO' action and deliver its result in an 'Event'.
ioAsEventLater :: IO a -> FrameworksMoment (AnyMoment Event a)
ioAsEventLater io =
  FrameworksMoment (ioAsEvent io >>= trim . fst)

--------------------------------------------------------------------------------
tag :: Functor f => a -> f b -> f a
tag = (<$)

constWhen :: Event t b -> a -> Event t (x -> a)
constWhen ev a = tag (const a) ev
