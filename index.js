const express = require('express');
const { Storage } = require('@google-cloud/storage');

const app = express();
const storage = new Storage();

app.use(express.json());

app.use('/', require('./routes/memo')(storage));

exports.memoApi = app;
