module Web.Config where

import Contract.Prelude

import Contract.Address (NetworkId(TestnetId))
import Contract.Monad (ConfigParams)
import Contract.Wallet (WalletSpec(ConnectToNami))
import Data.UInt (fromInt) as UInt

config :: ConfigParams ()
config =
  { ctlServerConfig: Just
      { host: "ctl-server.preview.ctl-runtime.staging.mlabs.city"
      , port: UInt.fromInt 443
      , path: Nothing
      , secure: true
      }
  , customLogger: Nothing
  , datumCacheConfig:
      { host: "ogmios-datum-cache.preview.ctl-runtime.staging.mlabs.city"
      , port: UInt.fromInt 443
      , path: Nothing
      , secure: true
      }
  , extraConfig: {}
  , logLevel: Info
  , networkId: TestnetId
  , ogmiosConfig:
      { host: "ogmios.preview.ctl-runtime.staging.mlabs.city"
      , port: UInt.fromInt 443
      , path: Nothing
      , secure: true
      }
  , suppressLogs: false
  , walletSpec: Just ConnectToNami
  }
