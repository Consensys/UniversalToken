FROM node:9.1-alpine

RUN apk --no-cache add git openssh g++ gcc libgcc libstdc++ linux-headers make python

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

RUN npm install solidity-coverage

ENTRYPOINT ["./node_modules/.bin/testrpc-sc", "--port", "8555"]