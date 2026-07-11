{ username, ... }:
let
  sshAuthSock = "/Users/${username}/.bitwarden-ssh-agent.sock";
in
{
  environment.variables = {
    SSH_AUTH_SOCK = sshAuthSock;
  };

  launchd.user.envVariables = {
    SSH_AUTH_SOCK = sshAuthSock;
  };
}
