const webpack = require('webpack');
const CopyPlugin = require('copy-webpack-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');

// this is where the bundle and it's depenendencies will be sent
const output_dir = require('path').resolve(__dirname, '../public/dist/');

module.exports = {
  entry: {
		chat: './chat.js'
	},
  output: {
		filename: "[name].bundle.js",
		path: output_dir
  },
  plugins: [
    new CleanWebpackPlugin(),
    new CopyPlugin({
      patterns: [
        'node_modules/bootstrap/dist/css/bootstrap.min.css'
      ]
    }),
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery'
    })
  ]
};
