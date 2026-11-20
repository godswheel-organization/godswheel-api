defmodule GodsWheel.EmailTemplates do
  def verification_email(user, verification_url, app_url) do
    first_name =
      user.full_name
      |> String.split()
      |> List.first()
      |> html_escape()

    email = html_escape(user.email)
    expiry = "24 hours"
    year = Date.utc_today().year

    html =
      verification_html()
      |> String.replace("{{first_name}}", first_name)
      |> String.replace("{{email}}", email)
      |> String.replace("{{verification_url}}", html_escape(verification_url))
      |> String.replace("{{app_url}}", html_escape(app_url))
      |> String.replace("{{link_expiry}}", expiry)
      |> String.replace("{{year}}", to_string(year))

    text = """
    Hi #{user.full_name},

    Thanks for joining GodsWheel. Confirm this is your email address to activate your account, then save sermons and write notes as you listen.

    Confirm your email: #{verification_url}

    This link works once and expires in #{expiry}. If you did not create this account, you can ignore this email.
    """

    %{html: html, text: text}
  end

  defp verification_html do
    """
    <!DOCTYPE html>
    <html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="x-apple-disable-message-reformatting">
      <meta name="format-detection" content="telephone=no, date=no, address=no, email=no, url=no">
      <meta name="color-scheme" content="light dark">
      <meta name="supported-color-schemes" content="light dark">
      <title>Confirm your email for GodsWheel</title>
      <!--[if mso]>
      <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
      <style>td, th, div, p, a, h1 { font-family: Arial, sans-serif; }</style>
      <![endif]-->
      <style>
        body { margin: 0; padding: 0; width: 100% !important; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
        table { border-collapse: collapse; mso-table-lspace: 0; mso-table-rspace: 0; }
        img { border: 0; outline: none; text-decoration: none; -ms-interpolation-mode: bicubic; }
        a { color: #A34E17; }
        .gw-link-break { word-break: break-all; overflow-wrap: anywhere; }
        @media (max-width: 620px) {
          .gw-card { width: 100% !important; border-radius: 0 !important; }
          .gw-pad { padding-left: 24px !important; padding-right: 24px !important; }
          .gw-h1 { font-size: 26px !important; line-height: 32px !important; }
        }
        @media (prefers-color-scheme: dark) {
          .gw-body, .gw-bg { background-color: #0F1220 !important; }
          .gw-card { background-color: #1B2036 !important; border-color: #394166 !important; }
          .gw-header { background-color: #0F1220 !important; border-bottom: 1px solid #394166 !important; }
          .gw-text, .gw-h1 { color: #F5F3ED !important; }
          .gw-muted { color: #B8BCCB !important; }
          .gw-rule { border-color: #394166 !important; }
          a.gw-link { color: #F28C4B !important; }
        }
      </style>
    </head>
    <body class="gw-body" style="margin:0; padding:0; background-color:#F5F3ED;">
      <div style="display:none; max-height:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px; color:#F5F3ED; opacity:0;">
        One tap to confirm your email and start listening on GodsWheel.
        &#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;
      </div>
      <table role="presentation" class="gw-bg" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F3ED;">
        <tr>
          <td align="center" style="padding:32px 12px;">
            <table role="presentation" class="gw-card" width="560" cellpadding="0" cellspacing="0" border="0" style="width:560px; max-width:560px; background-color:#FFFFFF; border:1px solid #E4E1D8; border-radius:16px; overflow:hidden;">
              <tr>
                <td class="gw-header gw-pad" style="background-color:#1B2036; padding:22px 32px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td style="padding-right:12px; vertical-align:middle;">
                        <img src="{{app_url}}/icons/pwa/icon-192x192.png" width="36" height="36" alt="" style="display:block; width:36px; height:36px; border-radius:10px;">
                      </td>
                      <td style="vertical-align:middle; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:20px; font-weight:700; color:#F5F3ED; letter-spacing:-0.2px;">
                        GodsWheel
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td class="gw-pad" style="padding:36px 40px 8px 40px;">
                  <h1 class="gw-h1" style="margin:0; font-family:Georgia, 'Times New Roman', serif; font-size:30px; line-height:36px; font-weight:400; color:#0F1220;">Confirm your email</h1>
                  <p class="gw-text" style="margin:20px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:16px; line-height:26px; color:#0F1220;">Hi {{first_name}},</p>
                  <p class="gw-text" style="margin:12px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:16px; line-height:26px; color:#0F1220;">
                    Thanks for joining GodsWheel. Confirm this is your email address to activate your account, then save sermons and write notes as you listen.
                  </p>
                </td>
              </tr>
              <tr>
                <td class="gw-pad" align="left" style="padding:28px 40px 0 40px;">
                  <!--[if mso]>
                  <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="{{verification_url}}" style="height:52px; v-text-anchor:middle; width:240px;" arcsize="24%" stroke="f" fillcolor="#F28C4B">
                    <w:anchorlock/>
                    <center style="color:#0F1220; font-family:Arial, sans-serif; font-size:16px; font-weight:bold;">Confirm my email</center>
                  </v:roundrect>
                  <![endif]-->
                  <!--[if !mso]><!-->
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td align="center" bgcolor="#F28C4B" style="border-radius:12px; background-color:#F28C4B;">
                        <a href="{{verification_url}}" target="_blank" style="display:inline-block; padding:15px 32px; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:16px; font-weight:700; line-height:22px; color:#0F1220; text-decoration:none; border-radius:12px;">Confirm my email</a>
                      </td>
                    </tr>
                  </table>
                  <!--<![endif]-->
                </td>
              </tr>
              <tr>
                <td class="gw-pad" style="padding:24px 40px 0 40px;">
                  <p class="gw-muted" style="margin:0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:14px; line-height:22px; color:#5A6077;">
                    This link works once and expires in {{link_expiry}}. If the button doesn&rsquo;t work, paste this into your browser:
                  </p>
                  <p style="margin:8px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:13px; line-height:20px;">
                    <a href="{{verification_url}}" target="_blank" class="gw-link gw-link-break" style="color:#A34E17; word-break:break-all;">{{verification_url}}</a>
                  </p>
                </td>
              </tr>
              <tr>
                <td class="gw-pad" style="padding:32px 40px 36px 40px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr><td class="gw-rule" style="border-top:1px solid #E4E1D8; font-size:0; line-height:0;">&nbsp;</td></tr>
                  </table>
                  <p class="gw-muted" style="margin:20px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:13px; line-height:20px; color:#5A6077;">
                    You&rsquo;re getting this because someone created a GodsWheel account with {{email}}. If that wasn&rsquo;t you, ignore this email: no account is activated without this step.
                  </p>
                  <p class="gw-muted" style="margin:12px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:13px; line-height:20px; color:#5A6077;">
                    <a href="{{app_url}}/report" target="_blank" class="gw-link" style="color:#A34E17;">Report a problem</a>
                    &nbsp;&middot;&nbsp;
                    <a href="{{app_url}}/privacy-policy" target="_blank" class="gw-link" style="color:#A34E17;">Privacy notice</a>
                  </p>
                </td>
              </tr>
            </table>
            <p class="gw-muted" style="margin:20px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:12px; line-height:18px; color:#8A8F9F;">&copy; {{year}} GodsWheel</p>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end

  def password_reset_email(user, reset_url, app_url, expiry_seconds) do
    first_name =
      user.full_name
      |> String.split()
      |> List.first()
      |> html_escape()

    email = html_escape(user.email)
    expiry = format_expiry(expiry_seconds)
    year = Date.utc_today().year

    html =
      password_reset_html()
      |> String.replace("{{first_name}}", first_name)
      |> String.replace("{{email}}", email)
      |> String.replace("{{reset_url}}", html_escape(reset_url))
      |> String.replace("{{app_url}}", html_escape(app_url))
      |> String.replace("{{link_expiry}}", expiry)
      |> String.replace("{{year}}", to_string(year))

    text = """
    Hi #{user.full_name},

    We got a request to reset the password for your GodsWheel account. Choose a new one using the link below.

    Choose a new password: #{reset_url}

    This link works once and expires in #{expiry}. If you did not request this, ignore this email: your password stays the same until the link is used.
    """

    %{html: html, text: text}
  end

  defp format_expiry(seconds) when seconds >= 60 and rem(seconds, 60) == 0 do
    minutes = div(seconds, 60)
    unit = if minutes == 1, do: "minute", else: "minutes"
    "#{minutes} #{unit}"
  end

  defp format_expiry(seconds) when seconds > 0 do
    unit = if seconds == 1, do: "second", else: "seconds"
    "#{seconds} #{unit}"
  end

  defp password_reset_html do
    """
    <!DOCTYPE html>
    <html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="x-apple-disable-message-reformatting">
      <meta name="format-detection" content="telephone=no, date=no, address=no, email=no, url=no">
      <meta name="color-scheme" content="light dark">
      <meta name="supported-color-schemes" content="light dark">
      <title>Reset your GodsWheel password</title>
      <!--[if mso]>
      <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
      <style>td, th, div, p, a, h1 { font-family: Arial, sans-serif; }</style>
      <![endif]-->
      <style>
        body { margin: 0; padding: 0; width: 100% !important; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
        table { border-collapse: collapse; mso-table-lspace: 0; mso-table-rspace: 0; }
        img { border: 0; outline: none; text-decoration: none; -ms-interpolation-mode: bicubic; }
        a { color: #A34E17; }
        .gw-link-break { word-break: break-all; overflow-wrap: anywhere; }
        @media (max-width: 620px) {
          .gw-card { width: 100% !important; border-radius: 0 !important; }
          .gw-pad { padding-left: 24px !important; padding-right: 24px !important; }
          .gw-h1 { font-size: 26px !important; line-height: 32px !important; }
        }
        @media (prefers-color-scheme: dark) {
          .gw-body, .gw-bg { background-color: #0F1220 !important; }
          .gw-card { background-color: #1B2036 !important; border-color: #394166 !important; }
          .gw-header { background-color: #0F1220 !important; border-bottom: 1px solid #394166 !important; }
          .gw-text, .gw-h1 { color: #F5F3ED !important; }
          .gw-muted { color: #B8BCCB !important; }
          .gw-rule { border-color: #394166 !important; }
          a.gw-link { color: #F28C4B !important; }
        }
      </style>
    </head>
    <body class="gw-body" style="margin:0; padding:0; background-color:#F5F3ED;">
      <div style="display:none; max-height:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px; color:#F5F3ED; opacity:0;">
        Use this link to choose a new password for your GodsWheel account.
        &#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;
      </div>
      <table role="presentation" class="gw-bg" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F3ED;">
        <tr>
          <td align="center" style="padding:32px 12px;">
            <table role="presentation" class="gw-card" width="560" cellpadding="0" cellspacing="0" border="0" style="width:560px; max-width:560px; background-color:#FFFFFF; border:1px solid #E4E1D8; border-radius:16px; overflow:hidden;">
              <tr>
                <td class="gw-header gw-pad" style="background-color:#1B2036; padding:22px 32px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td style="padding-right:12px; vertical-align:middle;">
                        <img src="{{app_url}}/icons/pwa/icon-192x192.png" width="36" height="36" alt="" style="display:block; width:36px; height:36px; border-radius:10px;">
                      </td>
                      <td style="vertical-align:middle; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:20px; font-weight:700; color:#F5F3ED; letter-spacing:-0.2px;">
                        GodsWheel
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td class="gw-pad" style="padding:36px 40px 8px 40px;">
                  <h1 class="gw-h1" style="margin:0; font-family:Georgia, 'Times New Roman', serif; font-size:30px; line-height:36px; font-weight:400; color:#0F1220;">Reset your password</h1>
                  <p class="gw-text" style="margin:20px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:16px; line-height:26px; color:#0F1220;">Hi {{first_name}},</p>
                  <p class="gw-text" style="margin:12px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:16px; line-height:26px; color:#0F1220;">
                    We got a request to reset the password for your GodsWheel account. Choose a new one with the button below.
                  </p>
                </td>
              </tr>
              <tr>
                <td class="gw-pad" align="left" style="padding:28px 40px 0 40px;">
                  <!--[if mso]>
                  <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="{{reset_url}}" style="height:52px; v-text-anchor:middle; width:316px;" arcsize="24%" stroke="f" fillcolor="#F28C4B">
                    <w:anchorlock/>
                    <center style="color:#0F1220; font-family:Arial, sans-serif; font-size:16px; font-weight:bold;">Choose a new password</center>
                  </v:roundrect>
                  <![endif]-->
                  <!--[if !mso]><!-->
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td align="center" bgcolor="#F28C4B" style="border-radius:12px; background-color:#F28C4B;">
                        <a href="{{reset_url}}" target="_blank" style="display:inline-block; padding:15px 32px; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:16px; font-weight:700; line-height:22px; color:#0F1220; text-decoration:none; border-radius:12px;">
                          Choose a new password
                        </a>
                      </td>
                    </tr>
                  </table>
                  <!--<![endif]-->
                </td>
              </tr>
              <tr>
                <td class="gw-pad" style="padding:24px 40px 0 40px;">
                  <p class="gw-muted" style="margin:0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:14px; line-height:22px; color:#5A6077;">
                    This link works once and expires in {{link_expiry}}. If the button doesn&rsquo;t work, paste this into your browser:
                  </p>
                  <p style="margin:8px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:13px; line-height:20px;">
                    <a href="{{reset_url}}" target="_blank" class="gw-link gw-link-break" style="color:#A34E17; word-break:break-all;">{{reset_url}}</a>
                  </p>
                </td>
              </tr>
              <tr>
                <td class="gw-pad" style="padding:32px 40px 36px 40px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr><td class="gw-rule" style="border-top:1px solid #E4E1D8; font-size:0; line-height:0;">&nbsp;</td></tr>
                  </table>
                  <p class="gw-muted" style="margin:20px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:13px; line-height:20px; color:#5A6077;">
                    You&rsquo;re getting this because a password reset was requested for {{email}}. If that wasn&rsquo;t you, ignore this email: your password stays the same until the link is used.
                  </p>
                  <p class="gw-muted" style="margin:12px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:13px; line-height:20px; color:#5A6077;">
                    <a href="{{app_url}}/report" target="_blank" class="gw-link" style="color:#A34E17;">Report a problem</a>
                    &nbsp;&middot;&nbsp;
                    <a href="{{app_url}}/privacy-policy" target="_blank" class="gw-link" style="color:#A34E17;">Privacy notice</a>
                  </p>
                </td>
              </tr>
            </table>
            <p class="gw-muted" style="margin:20px 0 0 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size:12px; line-height:18px; color:#8A8F9F;">&copy; {{year}} GodsWheel</p>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end

  defp html_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
