export default {
  js2svg: {
    pretty: true,
    indent: 2,
    eol: "lf",
  },
  plugins: [
    {
      name: "preset-default",
      params: {
        overrides: {
            // Disable problematic plugins
            convertShapeToPath: false, // subgraphs become black
        },
      },
    },
  ],
};
