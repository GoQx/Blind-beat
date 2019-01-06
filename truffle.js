// Allows us to use ES6 in our migrations and tests.
require('babel-register')

let HDWalletProvider = require('truffle-hdwallet-provider')

// 助记词
// let mnemonic = 'candy maple cake sugar pudding cream honey rich smooth crumble sweet treat'
let mnemonic = 'scout same naive genius cannon maze differ acquire penalty habit surround ice'

let ip = 'https://ropsten.infura.io/v3/788b2b5a40bd4a168b94e24aae5346c7'

// let provider = new HDWallet(mnemonic, ip)

module.exports = {
  networks: {
    ganache: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*' // Match any network id
    },

    ropsten: {
      provider: function () {
        return new HDWalletProvider(mnemonic, ip)
      },
      network_id: '1',
      gas: 4500000,
      gasPrice: 10000000000
    }
  }
}
