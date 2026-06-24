{ username, ... }:
{
  launchd.user.envVariables = {
    SSH_AUTH_SOCK = "/Users/${username}/.bitwarden-ssh-agent.sock";
  };
}
