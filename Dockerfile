FROM nickblah/lua:5.3-luarocks

RUN apt-get update && \
    apt-get -y install git gcc libev-dev
    
RUN luarocks install lua_cliargs 2.0-1 && \
    luarocks install luacov && \
    luarocks install busted 1.11.1-2 && \
    luarocks install lua-ev

# fix issue of busted 1.11.1-2, see https://github.com/Olivine-Labs/busted/issues/290
RUN cp /usr/local/bin/busted_bootstrap /usr/local/bin/busted