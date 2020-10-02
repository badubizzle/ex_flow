#!/bin/sh

BASE_PORT=3000
INCREMENT=1

port=$BASE_PORT
isfree=$(netstat -taln | grep $port)

while [[ -n "$isfree" ]]; do
    port=$[port+INCREMENT]
    isfree=$(netstat -taln | grep $port)
done

PORT=$port iex --sname exflow_$port --cookie 12345 -S mix phx.server