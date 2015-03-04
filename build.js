({
    baseUrl: 'lib',
    dir: 'build',

    paths: {
        //require is a reserved word
        'requireLib': 'require',
    },

    //Stub out the cs module after a build since
    //it will not be needed.
    stubModules: ['cs'],

    //Disable for quicker dev builds
    //optimize: "none",

    modules: [
        {
            name: 'main',
            //The optimization will load CoffeeScript to convert
            //the CoffeeScript files to plain JS. Use the exclude
            //directive so that the coffee-script module is not included
            //in the built file.
            exclude: ['coffee-script'],
            include: ['requireLib'],
        }
    ],
})
