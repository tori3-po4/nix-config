let
  symbol = trigger: replace: { inherit trigger replace; };
in
{
  services.espanso = {
    enable = true;

    configs.default = {
      show_notifications = false;
    };

    matches.base = {
      global_vars = [
        {
          name = "today";
          type = "date";
          params.format = "%Y-%m-%d";
        }
        {
          name = "now";
          type = "date";
          params.format = "%H:%M";
        }
        {
          name = "datetime";
          type = "date";
          params.format = "%Y-%m-%d %H:%M";
        }
      ];

      matches = [
        {
          trigger = ";date";
          replace = "{{today}}";
        }
        {
          trigger = ";time";
          replace = "{{now}}";
        }
        {
          trigger = ";dt";
          replace = "{{datetime}}";
        }
        {
          trigger = ";osewa";
          replace = "お世話になっております。";
        }
        {
          trigger = ";otsu";
          replace = "お疲れさまです。";
        }
        {
          trigger = ";yor";
          replace = "よろしくお願いいたします。";
        }
        {
          trigger = ";kakunin";
          replace = "ご確認よろしくお願いいたします。";
        }
      ];
    };

    matches.symbols = {
      matches = [
        (symbol ";or" "|")
        (symbol ";and" "&")
        (symbol ";at" "@")
        (symbol ";hash" "#")
        (symbol ";dol" "$")
        (symbol ";per" "%")
        (symbol ";hat" "^")
        (symbol ";til" "~")
        (symbol ";bquote" "`")
        (symbol ";quote" "'")
        (symbol ";dquote" "\"")
        (symbol ";col" ":")
        (symbol ";semi" ";")
        (symbol ";comma" ",")
        (symbol ";dot" ".")
        (symbol ";plus" "+")
        (symbol ";minus" "-")
        (symbol ";star" "*")
        (symbol ";sla" "/")
        (symbol ";back" "\\")
        (symbol ";eq" "=")
        (symbol ";neq" "!=")
        (symbol ";lt" "<")
        (symbol ";gt" ">")
        (symbol ";le" "<=")
        (symbol ";ge" ">=")
        (symbol ";arrow" "->")
        (symbol ";darrow" "=>")
        (symbol ";maru" "()")
        (symbol ";lmaru" "(")
        (symbol ";rmaru" ")")
        (symbol ";chu" "{}")
        (symbol ";lchu" "{")
        (symbol ";rchu" "}")
        (symbol ";kaku" "[]")
        (symbol ";lkaku" "[")
        (symbol ";rkaku" "]")
        (symbol ";yama" "<>")
        (symbol ";lyama" "<")
        (symbol ";ryama" ">")
      ];
    };
  };
}
