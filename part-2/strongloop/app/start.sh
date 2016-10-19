#!/bin/bash
npm install
if [ "$NODE_ENV" = "production" ]
then
  npm start
else
  npm run dev
fi
