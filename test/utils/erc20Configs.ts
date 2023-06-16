
export function getBnbConfig(bnb, bnbPriceFeed) {
  return [
    bnb.address, // _token
    18, // _tokenDecimals
    10000, // _tokenWeight
    75, // _minProfitBps,
    0, // _maxUsdgAmount
    false, // _isStable
    true // _isShortable
  ]
}

function getEthConfig(eth, ethPriceFeed) {
  return [
    eth.address, // _token
    18, // _tokenDecimals
    10000, // _tokenWeight
    75, // _minProfitBps
    0, // _maxUsdgAmount
    false, // _isStable
    true // _isShortable
  ]
}

export function getBtcConfig(btc, btcPriceFeed) {
  return [
    btc.address, // _token
    8, // _tokenDecimals
    10000, // _tokenWeight
    75, // _minProfitBps
    0, // _maxUsdgAmount
    false, // _isStable
    true // _isShortable
  ]
}

export function getDaiConfig(dai, daiPriceFeed) {
  return [
    dai.address, // _token
    18, // _tokenDecimals
    10000, // _tokenWeight
    75, // _minProfitBps
    0, // _maxUsdgAmount
    true, // _isStable
    false // _isShortable
  ]
}
