{ name = "odc-mre"
, dependencies =
  [ "aff"
  , "cardano-transaction-lib"
  , "halogen"
  , "ordered-collections"
  , "uint"
  , "web-dom"
  , "web-html"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
