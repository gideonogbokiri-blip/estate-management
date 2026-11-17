const { getApp } = require('./_app');

module.exports = async (request, response) => {
  const app = await getApp();
  const server = app.getHttpAdapter().getInstance();
  return server(request, response);
};
