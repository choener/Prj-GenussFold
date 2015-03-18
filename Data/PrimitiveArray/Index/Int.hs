
module Data.PrimitiveArray.Index.Int where

import Data.Vector.Fusion.Stream.Monadic (flatten,map,Step(..))
import Data.Vector.Fusion.Stream.Size
import Prelude hiding (map)

import Data.PrimitiveArray.Index.Class



instance Index Int where
  linearIndex _ _ k = k
  {-# Inline linearIndex #-}
  smallestLinearIndex _ = error "still needed?"
  {-# Inline smallestLinearIndex #-}
  largestLinearIndex h = h
  {-# Inline largestLinearIndex #-}
  size _ h = h+1
  {-# Inline size #-}
  inBounds l h k = l <= k && k <= h
  {-# Inline inBounds #-}

instance IndexStream z => IndexStream (z:.Int) where
  streamUp (ls:.l) (hs:.h) = flatten mk step Unknown $ streamUp ls hs
    where mk z = return (z,l)
          step (z,k)
            | k > h     = return $ Done
            | otherwise = return $ Yield (z:.k) (z,k+1)
          {-# Inline [0] mk   #-}
          {-# Inline [0] step #-}
  {-# Inline streamUp #-}
  streamDown (ls:.l) (hs:.h) = flatten mk step Unknown $ streamDown ls hs
    where mk z = return (z,h)
          step (z,k)
            | k < l     = return $ Done
            | otherwise = return $ Yield (z:.k) (z,k-1)
          {-# Inline [0] mk   #-}
          {-# Inline [0] step #-}
  {-# Inline streamDown #-}

instance IndexStream Int where
  streamUp l h = map (\(Z:.k) -> k) $ streamUp (Z:.l) (Z:.h)
  {-# Inline streamUp #-}
  streamDown l h = map (\(Z:.k) -> k) $ streamDown (Z:.l) (Z:.h)
  {-# Inline streamDown #-}

