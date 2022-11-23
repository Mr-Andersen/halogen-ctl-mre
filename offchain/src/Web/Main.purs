module Web.Main where

import Contract.Prelude

import Contract.Address (getWalletAddress)
import Contract.Log (logInfo')
import Contract.Monad (Contract, liftedM, runContractInEnv, withContractEnv)
import Contract.Utxos (UtxoMap, utxosAt)
import Data.Map (size) as Map
import Effect.Aff.Class (class MonadAff, liftAff)
import Halogen
  ( Component
  , HalogenM
  , HalogenQ
  , defaultEval
  , hoist
  , lift
  , mkComponent
  , mkEval
  , put
  )
import Halogen.Aff (runHalogenAff)
import Halogen.Aff.Util (selectElement)
import Halogen.HTML (ComponentHTML)
import Halogen.HTML as H
import Halogen.HTML.Events as HE
import Halogen.VDom.Driver (runUI)
import Web.Config (config) as Config
import Web.DOM.ChildNode (remove) as Web.DOM
import Web.DOM.ParentNode (QuerySelector(QuerySelector))
import Web.HTML.HTMLElement (HTMLElement)
import Web.HTML.HTMLElement (toChildNode) as Web.HTML

main :: Effect Unit
main = runHalogenAff do
  body <- selectElement' "#application"
  withContractEnv Config.config \contractEnv -> void do
    selectElement' "#preload-spinner"
      >>= Web.HTML.toChildNode
      >>> Web.DOM.remove
      >>> liftEffect
    runUI
      ( hoist
          ( \c -> runContractInEnv contractEnv do
              -- liftAff $ AVar.take lock
              logInfo' "enter runContractInEnv"
              x <- c
              logInfo' "exit runContractInEnv"
              -- liftAff $ AVar.put unit lock
              pure x
          )
          component
      )
      unit
      body

selectElement' :: forall m. MonadAff m => String -> m HTMLElement
selectElement' s = do
  mb <- liftAff <<< selectElement $ QuerySelector s
  liftEffect $ fromJustEff "No #preload-spinner in document" mb

type AppM = Contract ()

component :: forall q o. Component q Input o AppM
component = mkComponent { initialState, render, eval }

type Input = Unit

data State
  = Initial
  | Ready UtxoMap

data Action
  = Initialize
  | ButtonPush

instance Show Action where
  show Initialize = "Initialize"
  show ButtonPush = "ButtonPush"

initialState :: Input -> State
initialState _ = Initial

render :: forall s. State -> ComponentHTML Action s AppM
render Initial = button
render (Ready m) = H.div_ [ button, H.text $ show (Map.size m) <> " utxos" ]

button :: forall s. ComponentHTML Action s AppM
button = H.button [ HE.onClick \_ -> ButtonPush ] [ H.text "Press" ]

eval ::
  forall query slots input output.
  HalogenQ query Action input ~>
    HalogenM State Action slots output AppM
eval = mkEval defaultEval
  { initialize = Just Initialize, handleAction = handleAction }

handleAction ::
  forall s o.
  Action ->
  HalogenM State Action s o AppM Unit
handleAction action = do
  ownUtxos <- lift do
    logInfo' $ "action = " <> show action
    logInfo' "Run getWalletAddress"
    ownAddr <- liftedM "Failed `getWalletAddress`" getWalletAddress
    logInfo' "Run utxosAt"
    utxos <- liftedM "Failed `utxosAt self`" $ utxosAt ownAddr
    logInfo' $ "Query end: " <> show (Map.size utxos) <> " utxo"
    pure utxos
  put $ Ready ownUtxos
