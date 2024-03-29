
-- | Instance code for @Inside@, @Outside@, and @Complement@ indices.
--
-- TODO actual @Outside@ and @Complement@ code ...
--
-- TODO we have quite a lot of @subword i j@ code where only the @type@
-- is different; check if @coerce@ yields improved performance or if the
-- compiler optimizes this out!

module ADPfusion.Subword.SynVar.Indices where

import Data.Proxy
import Data.Vector.Fusion.Stream.Monadic (map,Stream,head,mapM,Step(..),filter,flatten)
import Data.Vector.Fusion.Util (delay_inline)
import Prelude hiding (map,head,mapM,filter)
import Debug.Trace

import Data.PrimitiveArray hiding (map)

import ADPfusion.Core
import ADPfusion.Subword.Core



type instance LeftPosTy (IStatic d) (TwITbl bo lo m arr EmptyOk (Subword I) x) (Subword I) = IVariable d
type instance LeftPosTy (IStatic d) (TwITblBt bo lo arr EmptyOk (Subword I) x mB mF r) (Subword I) = IVariable d

type instance LeftPosTy (IVariable d) (TwITbl bo lo m arr EmptyOk (Subword I) x) (Subword I) = IVariable d
type instance LeftPosTy (IVariable d) (TwITblBt bo lo arr EmptyOk (Subword I) x mB mF r) (Subword I) = IVariable d



-- |
-- @
-- Table: Inside
-- Grammar: Inside
--
-- The minSize condition for @IStatic@ is guaranteed via the use of
-- @tableStreamIndex@ (not here, in individual synvars), where @j@ is set
-- to @j-1@ for the next-left symbol!
-- @

instance
  ( AddIndexDenseContext ps elm x0 i0 cs c us (Subword I) is (Subword I)
  , MinSize c
  )
  => AddIndexDense (ps:.IStatic d) elm (cs:.c) (us:.Subword I) (is:.Subword I) where
  addIndexDenseGo Proxy (cs:._) (ubs:.._) (us:..LtSubword u) (is:.Subword (i:.j))
    = map (\(SvS s t y') -> let RiSwI l = getIndex (getIdx s) (Proxy :: PRI is (Subword I))
                                lj = subword l j
                            in  SvS s (t:.lj) (y' :.: RiSwI j) )
    . addIndexDenseGo (Proxy :: Proxy ps) cs ubs us is
  {-# Inline addIndexDenseGo #-}

instance
  ( AddIndexDenseContext ps elm x0 i0 cs c us (Subword I) is (Subword I)
  , MinSize c
  )
  => AddIndexDense (ps:.IVariable d) elm (cs:.c) (us:.Subword I) (is:.Subword I) where
--{{{
  {-# Inline addIndexDenseGo #-}
  addIndexDenseGo Proxy (cs:.c) (ubs:.._) (us:..LtSubword u) (is:.Subword (i:.j))
    = seq csize . flatten mk step . addIndexDenseGo (Proxy :: Proxy ps) cs ubs us is
    where
      {-# Inline [0] mk   #-}
      mk   svS = let RiSwI l = getIndex (getIdx $ sS svS) (Proxy :: PRI is (Subword I))
                 in  seq l . return $ svS :. (j - l - csize)
      {-# Inline [0] step #-}
      step (SvS s t y' :. zz)
        | zz >= 0 = do let RiSwI k = getIndex (getIdx s) (Proxy :: PRI is (Subword I))
                           l = j - zz ; kl = subword k l
                       return $ Yield (SvS s (t:.kl) (y' :.: RiSwI l)) (SvS s t y' :. zz-1)
        | otherwise =  return $ Done
      !csize = minSize c
--}}}

-- -- |
-- -- @
-- -- Table: Outside
-- -- Grammar: Outside
-- -- @
-- --
-- -- TODO Take care of @c@ in all cases to correctly handle @NonEmpty@ tables
-- -- and the like.
-- 
-- instance
--   ( AddIndexDenseContext s x0 i0 us (Subword O) cs c is (Subword O)
--   ) => AddIndexDense s (us:.Subword O) (cs:.c) (is:.Subword O) where
--   addIndexDenseGo (cs:.c) (vs:.OStatic (di:.dj)) (lbs:._) (ubs:._) (us:.u) (is:.Subword (i:.j))
--     = map (\(SvS s t y') -> let RiSwO _ _ k _ = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                                 kj = subword k (j+dj)
--                             in  SvS s (t:.kj) (y' :.: RiSwO i j k (j+dj)) )
--     . addIndexDenseGo cs vs lbs ubs us is
--   addIndexDenseGo (cs:.c) (vs:.ORightOf (di:.dj)) (lbs:._) (ubs:._) (us:.Subword (_:.h)) (is:.Subword (i:.j))
--     = flatten mk step . addIndexDenseGo cs vs lbs ubs us is
--     where mk svS = return (svS :. j+dj)
--           step (svS@(SvS s t y') :. l)
--             | l <= h = let RiSwO k _ _ _ = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                            kl = subword k l
--                            jdj = j+dj
--                        in  return $ Yield (SvS s (t:.kl) (y' :.: RiSwO jdj jdj k l)) (svS :. l+1)
--             | otherwise = return Done
--           {-# Inline [0] mk   #-}
--           {-# Inline [0] step #-}
--   addIndexDenseGo _ (_:.OFirstLeft _) _ _ _ _ = error "SynVar.Indices.Subword : OFirstLeft"
--   addIndexDenseGo _ (_:.OLeftOf    _) _ _ _ _ = error "SynVar.Indices.Subword : LeftOf"
--   {-# Inline addIndexDenseGo #-}
-- 
-- -- |
-- -- @
-- -- Table: Inside
-- -- Grammar: Outside
-- -- @
-- --
-- -- TODO take care of @c@
-- 
-- instance
--   ( AddIndexDenseContext s x0 i0 us (Subword I) cs c is (Subword O)
--   , MinSize c
--   ) => AddIndexDense s (us:.Subword I) (cs:.c) (is:.Subword O) where
--   addIndexDenseGo (cs:.c) (vs:.OStatic (di:.dj)) (lbs:._) (ubs:._) (us:.u) (is:.Subword (i:.j))
--     = map (\(SvS s t y') -> let RiSwO _ k li l = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                                 klI = subword (k-dj) (l-dj)
--                             in  SvS s (t:.klI) (y':.:RiSwO (k-dj) (l-dj) li l))
--     . addIndexDenseGo cs vs lbs ubs us is
--   addIndexDenseGo (cs:.c) (vs:.ORightOf d) (lbs:._) (ubs:._) (us:.u) (is:.Subword (i:.j))
--     = flatten mk step . addIndexDenseGo cs vs lbs ubs us is
--     where mk svS = let RiSwO _ l _ _ = getIndex (getIdx $ sS svS) (Proxy :: PRI is (Subword O))
--                    in  return (svS :. l :. l + csize)
--           step (svS@(SvS s t y') :. k :. l)
--             | l <= oj   = return $ Yield (SvS s (t:.klI) (y' :.: RiSwO k l oi oj))
--                                          (svS :. k :. l+1)
--             | otherwise = return $ Done
--             where RiSwO _ _ oi oj = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                   klI = subword k l
--           csize = minSize c
--           {-# Inline [0] mk   #-}
--           {-# Inline [0] step #-}
--   addIndexDenseGo (cs:.c) (vs:.OFirstLeft (di:.dj)) (lbs:._) (ubs:._) (us:.u) (is:.Subword (i:.j))
--     = map (\(SvS s t y') -> let RiSwO _ k l lj = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                                 klI = subword k $ i - di
--                             in  SvS s (t:.klI) (y' :.: RiSwO k (i-di) l lj))
--     . addIndexDenseGo cs vs lbs ubs us is
--   addIndexDenseGo (cs:.c) (vs:.OLeftOf d) (lbs:._) (ubs:._) (us:.u) (is:.Subword (i:.j))
--     = flatten mk step . addIndexDenseGo cs vs lbs ubs us is
--     where mk svS = let RiSwO _ l _ _ = getIndex (getIdx $ sS svS) (Proxy :: PRI is (Subword O))
--                    in  return $ svS :. l
--           step (svS@(SvS s t y') :. l)
--             | l <= i    = let RiSwO _ k oi oj = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                               klI = subword k l
--                           in  return $ Yield (SvS s (t:.klI) (y' :.: RiSwO k l oi oj))
--                                              (svS :. l+1)
--             | otherwise = return $ Done
--           csize = minSize c
--           {-# Inline [0] mk   #-}
--           {-# Inline [0] step #-}
--   {-# Inline addIndexDenseGo #-}
-- 
-- 
-- 
-- 
-- -- TODO
-- -- @
-- -- Table: Inside
-- -- Grammar: Complement
-- -- @
-- 
-- instance
--   ( AddIndexDenseContext s x0 i0 us (Subword I) cs c is (Subword C)
--   ) => AddIndexDense s (us:.Subword I) (cs:.c) (is:.Subword C) where
--   addIndexDenseGo (cs:.c) (vs:.Complemented) (lbs:._) (ubs:._) (us:.u) (is:.i)
--     = map (\(SvS s t y') -> let kk@(RiSwC ki kj) = getIndex (getIdx s) (Proxy :: PRI is (Subword C))
--                             in  SvS s (t:.subword ki kj) (y':.:kk))
--     . addIndexDenseGo cs vs lbs ubs us is
--   {-# Inline addIndexDenseGo #-}
-- 
-- -- TODO
-- -- @
-- -- Table: Outside
-- -- Grammar: Complement
-- -- @
-- 
-- instance
--   ( AddIndexDenseContext s x0 i0 us (Subword O) cs c is (Subword C)
--   ) => AddIndexDense s (us:.Subword O) (cs:.c) (is:.Subword C) where
--   addIndexDenseGo (cs:.c) (vs:.Complemented) (lbs:._) (ubs:._) (us:.u) (is:.i)
--     = map (\(SvS s t y') -> let kk@(RiSwC ki kj) = getIndex (getIdx s) (Proxy :: PRI is (Subword C))
--                             in  SvS s (t:.subword ki kj) (y':.:kk))
--     . addIndexDenseGo cs vs lbs ubs us is
--   {-# Inline addIndexDenseGo #-}
-- 
-- -- |
-- -- @
-- -- Table: Complement
-- -- Grammar: Complement
-- -- @
-- 
-- instance
--   ( AddIndexDenseContext s x0 i0 us (Subword C) cs c is (Subword C)
--   ) => AddIndexDense s (us:.Subword C) (cs:.c) (is:.Subword C) where
--   addIndexDenseGo (cs:.c) (vs:.Complemented) (lbs:._) (ubs:._) (us:.u) (is:.i)
--     = map (\(SvS s t y') -> let k = getIndex (getIdx s) (Proxy :: PRI is (Subword C))
--                                 RiSwC ki kj = k
--                               in  SvS s (t:.subword ki kj) (y':.:k))
--     . addIndexDenseGo cs vs lbs ubs us is
--   {-# Inline addIndexDenseGo #-}

