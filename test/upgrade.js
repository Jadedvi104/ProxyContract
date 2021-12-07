const ProxyContract = artifacts.require('Proxy');
const Marketplace = artifacts.require('ECIOMarketplace');
const NFTcore = artifacts.require('ECIOTEST');

contract('', ([admin, _]) => {
  it('Proxy should call getListingPrice from Marketplace', async () => {
    let data, gas, gasPrice, txData, listingPrice, implementationVal, adminVal;
    const proxy = await ProxyContract.new();
    const market = await Marketplace.new();
    const marketWeb3 = new web3.eth.Contract(
      market.abi,
      market.address
    );

    //Test Implementation1
    await proxy.upgrade(market.address);
    tx = marketWeb3.methods.getListingPrice();
    data = tx.encodeABI();
    gas = await tx.estimateGas({from: admin});
    gasPrice = await web3.eth.getGasPrice();
    txData = {
      from: admin,
      to: proxy.address,
      data,
      gas: gas + 50000,
      gasPrice
    };
    await web3.eth.sendTransaction(txData);
    tx = marketWeb3.methods.getListingPrice();
    data = tx.encodeABI();
    txData = {
      from: admin,
      to: proxy.address,
      data: data,
    };
    listingPrice = await web3.eth.call(txData);
    assert(web3.utils.listingPrice === 100);
    // implementationVal = await proxy.implementation();
    // assert(implementationVal === market.address);
    // adminVal = await proxy.admin();
    // assert(adminVal === admin);
  });
});
