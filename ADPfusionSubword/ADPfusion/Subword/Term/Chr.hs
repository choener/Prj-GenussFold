
module ADPfusion.Subword.Term.Chr where

import           Data.Proxy
import           Data.Strict.Tuple
import           Data.Vector.Fusion.Stream.Monadic as S
import           Data.Vector.Fusion.Util (delay_inline)
import           Debug.Trace
import           GHC.Exts
import           Prelude hiding (map)
import qualified Data.Vector.Generic as VG

import           Data.PrimitiveArray hiding (map)

import           ADPfusion.Core
import           ADPfusion.Subword.Core



type instance LeftPosTy (IStatic d)   (Chr r x) (Subword I) = IStatic   d
type instance LeftPosTy (IVariable d) (Chr r x) (Subword I) = IVariable d



instance
  forall pos posLeft m ls i r x
  . ( TermStream m (Z:.pos) (TermSymbol M (Chr r x)) (Elm (Term1 (Elm ls (Subword i))) (Z:.Subword i)) (Z:.Subword i)
    , posLeft ~ LeftPosTy pos (Chr r x) (Subword i)
    , TermStaticVar pos (Chr r x) (Subword i)
    , MkStream m posLeft ls (Subword i)
  )
  ⇒ MkStream m pos (ls :!: (Chr r x)) (Subword i) where
  mkStream Proxy (ls :!: Chr f xs) grd us is
    = S.map (\(ss,ee,ii) -> ElmChr ee ii ss)
    . addTermStream1 (Proxy :: Proxy pos) (Chr f xs) us is
    $ mkStream (Proxy :: Proxy posLeft)
               ls
               (termStaticCheck (Proxy :: Proxy pos) (Chr f xs) us is grd)
               us
               (termStreamIndex (Proxy :: Proxy pos) (Chr f xs) is)
  {-# Inline mkStream #-}



-- |
--
-- NOTE We do not run 'staticCheck'. Running @staticCheck@ costs about
-- @10%@ performance and we assume that the frontend will take care of
-- correct indices anyway.
--
-- TODO lets see if this is still true with the new @grd@ system

instance
  ( TermStreamContext m ps ts s x0 i0 is (Subword I)
  ) => TermStream m (ps:.IStatic d) (TermSymbol ts (Chr r x)) s (is:.Subword I) where
  {-# Inline termStream #-}
  termStream Proxy (ts:|Chr f xs) (us:..u) (is:.Subword (i:.j))
    = map (\(TState s ii ee) ->
              TState s (ii:.: RiSwI j) (ee:.f xs (j-1)) )
    . termStream (Proxy :: Proxy ps) ts us is

instance
  ( TermStreamContext m ps ts s x0 i0 is (Subword I)
  ) => TermStream m (ps:.IVariable d) (TermSymbol ts (Chr r x)) s (is:.Subword I) where
  termStream Proxy (ts:|Chr f xs) (us:..u) (is:.Subword (i:.j))
    = map (\(TState s ii ee) ->
              let RiSwI l = getIndex (getIdx s) (Proxy :: PRI is (Subword I))
              in  TState s (ii:.:RiSwI (l+1)) (ee:.f xs l) )
    . termStream (Proxy :: Proxy ps) ts us is
  {-# Inline termStream #-}

-- instance
--   ( TermStreamContext m ts s x0 i0 is (Subword O)
--   ) => TermStream m (TermSymbol ts (Chr r x)) s (is:.Subword O) where
--   termStream (ts:|Chr f xs) (cs:.OStatic (di:.dj)) (us:.u) (is:.Subword (i:.j))
--     = map (\(TState s ii ee) ->
--               let RiSwO _ k oi oj = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                   l              = k - dj
--               in  TState s (ii:.: RiSwO k (k+1) oi oj) (ee:.f xs k) )
--     . termStream ts cs us is
--   --
--   termStream (ts:|Chr f xs) (cs:.ORightOf (di:.dj)) (us:.u) (is:.i)
--     = map (\(TState s ii ee) ->
--               let RiSwO _ k oi oj = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--                   l              = k - dj - 1
--               in  TState s (ii:.:RiSwO (k-1) k oi oj) (ee:.f xs l) )
--     . termStream ts cs us is
--   --
--   termStream (ts:|Chr f xs) (cs:.OFirstLeft (di:.dj)) (us:.u) (is:.i)
--     = map (\(TState s ii ee) ->
--               let RiSwO _ k oi oj = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--               in  TState s (ii:.:RiSwO k (k+1) oi oj) (ee:.f xs k) )
--     . termStream ts cs us is
--   --
--   termStream (ts:|Chr f xs) (cs:.OLeftOf (di:.dj)) (us:.u) (is:.i)
--     = map (\(TState s ii ee) ->
--               let RiSwO _ k oi oj = getIndex (getIdx s) (Proxy :: PRI is (Subword O))
--               in  TState s (ii:.:RiSwO k (k+1) oi oj) (ee:.f xs k) )
--     . termStream ts cs us is
--   {-# Inline termStream #-}

instance TermStaticVar (IStatic d) (Chr r x) (Subword I) where
  termStreamIndex Proxy _ (Subword (i:.j)) = subword i (j-1)
  termStaticCheck Proxy _ _ _ grd = grd
  {-# Inline [0] termStreamIndex #-}
  {-# Inline [0] termStaticCheck #-}

instance TermStaticVar (IVariable d) (Chr r x) (Subword I) where
  termStreamIndex Proxy _ (Subword (i:.j)) = subword i (j-1)
  termStaticCheck Proxy _ _ _ grd = grd
  {-# Inline [0] termStreamIndex #-}
  {-# Inline [0] termStaticCheck #-}

--instance TermStaticVar (Chr r x) (Subword O) where
--  termStaticVar _ (OStatic    (di:.dj)) _ = OStatic    (di  :.dj+1)
--  termStaticVar _ (ORightOf   (di:.dj)) _ = ORightOf   (di  :.dj+1)
--  termStaticVar _ (OFirstLeft (di:.dj)) _ = OFirstLeft (di+1:.dj  )
--  termStaticVar _ (OLeftOf    (di:.dj)) _ = OLeftOf    (di+1:.dj  )
--  termStreamIndex _ _ sw = sw
--  termStaticCheck _ _ = 1#
--  {-# Inline [0] termStaticVar   #-}
--  {-# Inline [0] termStreamIndex #-}
--  {-# Inline [0] termStaticCheck #-}

