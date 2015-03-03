require.config({ baseUrl: "/lib"});

require(['jquery', 'cs!flocking'], function($, Flocking) {
  canvas = document.getElementById("experiment");
  var fw = new Flocking.FlockingWorld(canvas);
  fw.run();
});
