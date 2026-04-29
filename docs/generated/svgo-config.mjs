// This is the SVGO configuration file used to optimize SVG files.
// See https://github.com/svg/svgo for more details on configuration options.
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
            convertShapeToPath: false, // causes subgraphs to become black
        },
      },
    },
  ],
};
