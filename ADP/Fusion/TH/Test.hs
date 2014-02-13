{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}

module ADP.Fusion.TH.Test where

import           Data.List
import           Language.Haskell.TH
import           Language.Haskell.TH.Syntax
import qualified Data.Vector.Fusion.Stream.Monadic as SM

import           ADP.Fusion.TH



data Bla a b x r = Bla
  { fun1 :: a      -> x
  , fun2 :: a -> b -> x
  , h   :: forall m . Monad m => SM.Stream m x -> r
  }

makeAlgebraProductH ['h] ''Bla

