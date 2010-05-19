-- | @List@ functions with type limited to use @ListT@.
-- This might come useful for type interference.
--
-- Functions where the @List@ is an input type and not only the result type do not need special limited versions.

module Control.Monad.Trans.List.Funcs
    ( iterateM, repeatM, fromList
    ) where

import Control.Monad.ListT (ListT)
import qualified Data.List.Class as ListFuncs

iterateM :: Monad m => (a -> m a) -> m a -> ListT m a
iterateM = ListFuncs.iterateM

repeatM :: Monad m => m a -> ListT m a
repeatM = ListFuncs.repeatM

fromList :: Monad m => [a] -> ListT m a
fromList = ListFuncs.fromList
