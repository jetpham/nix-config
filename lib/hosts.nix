{
  framework = {
    hostname = "framework";
    role = "personal";
    email = "jet@extremist.software";
    features = {
      heyteaMcp = true;
      linearMcp = false;
      tailscale = true;
    };
  };

  framework-work = {
    hostname = "framework-work";
    role = "work";
    email = "jet@corp.primitive.dev";
    features = {
      heyteaMcp = false;
      linearMcp = true;
      tailscale = false;
    };
  };
}
