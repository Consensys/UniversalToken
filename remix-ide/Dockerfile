FROM node:9.1-alpine

RUN apk update \                                                                                                                                                                                                                        
    && apk add ca-certificates wget \                                                                                                                                                                                                      
    && update-ca-certificates \
    && apk --no-cache add git openssh g++ gcc libgcc libstdc++ linux-headers make python

RUN mkdir -p /usr/src/
WORKDIR /usr/src/

RUN git clone https://github.com/ethereum/remix-ide.git
WORKDIR /usr/src/remix-ide

RUN npm install && \
    npm run setupremix && \
    npm cache clean --force && \
    npm run build

COPY ./contracts /usr/src/contracts

EXPOSE 8080 