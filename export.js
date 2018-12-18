fs = require('fs-extra');

const inputFile = 'build/contracts/ERC1400.json';
const outputFile = '.export.json';

const networkID = '3';

fs.remove(outputFile, function(err){
  if (err) return console.error(err);

  fs.readJson(inputFile, function(err, inputData) {

    if(!err) {
      const contractAbi = inputData.abi;

      let contractAddress;
      if(inputData.networks[networkID]) {
        contractAddress = inputData.networks[networkID].address;
      } else {
        contractAddress = "Undefined - Contract not deployed on network ".concat(networkID);
      }

      console.log("Contract deployed at address: ", contractAddress, "on network with ID: ", networkID);
      if(contractAddress.length == 42) {
        fs.outputJson(outputFile, {address: contractAddress, abi: contractAbi}, function(err) {
          if (err) return console.error(err);

          fs.readJson(outputFile, function(err, outputData) {
            console.log("Parameters copied in file .export.txt");
          });

        });
      } else {
        console.log("No contract deployed on network with ID: ", networkID);
      }

    } else {
      console.log("Error, contract not deployed yet, call 'truffle migrate' to deploy it.");
    }

  });

});
