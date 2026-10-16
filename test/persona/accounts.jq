# Two complete synthetic accounts. The nondefault account must be checked too.
. + {
  "alice/email/accounts": "personal shared",
  "alice/email/default-account": "shared",
  "alice/blobs/accounts": "personal shared",
  "alice/blobs/default-account": "personal"
}
| reduce ["personal", "shared"][] as $label (.;
    ("alice/email/" + $label + "/") as $email
    | ("alice/blobs/" + $label + "/") as $blobs
    | . + {
        ($email + "address"): ($label + "@example.test"),
        ($email + "display-name"): $label,
        ($email + "signing-fingerprint"): "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        ($blobs + "provider"): "b2",
        ($blobs + "bucket"): $label,
        ($blobs + "key-id"): "synthetic-id",
        ($blobs + "application-key"): "synthetic-key"
      }
    | reduce ["imap", "smtp"][] as $transport (.;
        ($email + $transport + "/") as $path
        | . + {
            ($path + "host"): "mail.example.test",
            ($path + "port"): (if $transport == "imap" then "993" else "465" end),
            ($path + "encryption"): "tls",
            ($path + "username"): $label,
            ($path + "password"): "quoted ' $(false)\n\n"
          }
      )
  )
