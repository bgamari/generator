{-# LANGUAGE FlexibleInstances, FunctionalDependencies, MultiParamTypeClasses, UndecidableInstances #-}

module Data.List.Class (
  -- | The List typeclass
  BaseList(..), FoldList(..), List (..), ListItem (..),
  -- | List operations for MonadPlus
  cons, fromList, filter,
  -- | Standard list operations for FoldList instances
  takeWhile, genericLength, scanl,
  -- | Standard list operations for List instances
  genericDrop, genericTake,
  -- | Non standard FoldList operations
  foldlL, execute, toList,
  -- | Non standard List operations
  splitAtL,
  -- | For implementing FoldList instances from List
  listFoldrL
  ) where

import Control.Monad (MonadPlus(..), ap, join, liftM)
import Control.Monad.Identity (Identity(..))
import Data.Foldable (Foldable, foldl')
import Prelude hiding (filter, takeWhile, scanl)

data ListItem l a =
  Nil |
  Cons { headL :: a, tailL :: l a }

class (MonadPlus l, Monad m) => BaseList l m | l -> m where
  joinL :: m (l b) -> l b

class BaseList l m => FoldList l m | l -> m where
  foldrL :: (a -> m b -> m b) -> m b -> l a -> m b

class BaseList l m => List l m | l -> m where
  unCons :: l a -> m (ListItem l a)

instance BaseList [] Identity where
  joinL = runIdentity

instance List [] Identity where
  unCons [] = Identity Nil
  unCons (x : xs) = Identity $ Cons x xs

instance FoldList [] Identity where
  foldrL = listFoldrL

cons :: MonadPlus m => a -> m a -> m a
cons = mplus . return

fromList :: (MonadPlus m, Foldable t) => t a -> m a
fromList = foldl' (flip (mplus . return)) mzero

filter :: MonadPlus m => (a -> Bool) -> m a -> m a
filter cond =
  (>>= f)
  where
    f x
      | cond x = return x
      | otherwise = mzero

listFoldrL :: List l m => (a -> m b -> m b) -> m b -> l a -> m b
listFoldrL consFunc nilFunc list = do
  item <- unCons list
  case item of
    Nil -> nilFunc
    Cons x xs -> consFunc x $ listFoldrL consFunc nilFunc xs

-- for foldlL and scanl
foldlL' :: FoldList l m =>
  (a -> m c -> c) -> (a -> c) -> (a -> b -> a) -> a -> l b -> c
foldlL' process end step startVal =
  t startVal . foldrL astep (return end)
  where
    astep x rest = return $ (`t` rest) . (`step` x)
    t cur = process cur . (`ap` return cur)

foldlL :: FoldList l m => (a -> b -> a) -> a -> l b -> m a
foldlL step startVal =
  foldlL' (const join) id astep (return startVal)
  where
    astep rest x = liftM (`step` x) rest

scanl :: FoldList l m => (a -> b -> a) -> a -> l b -> l a
scanl =
  foldlL' t $ const mzero
  where
    t cur = cons cur . joinL

takeWhile :: FoldList l m => (a -> Bool) -> l a -> l a
takeWhile cond =
  joinL . foldrL step (return mzero)
  where
    step x
      | cond x = return . cons x . joinL
      | otherwise = const $ return mzero

splitAtL :: (Integral i, List l m) => i -> l a -> m (l a, l a)
splitAtL count list
  | count <= 0 = return (mzero, list)
  | otherwise = do
    item <- unCons list
    case item of
      Nil -> return (mzero, mzero)
      Cons x xs -> do
        (pre, post) <- splitAtL (count - 1) xs
        return (cons x pre, post)

genericDrop :: (Integral i, List l m) => i -> l a -> l a
genericDrop count = joinL . liftM snd . splitAtL count

genericTake :: (Integral i, List l m) => i -> l a -> l a
genericTake count = joinL . liftM fst . splitAtL count

toList :: FoldList m i => m a -> i [a]
toList =
  foldrL step $ return []
  where
    step = liftM . (:)

genericLength :: (Integral i, FoldList l m) => l a -> m i
genericLength = foldlL (const . (+ 1)) 0

execute :: FoldList l m => l a -> m ()
execute = foldrL (const id) $ return ()

