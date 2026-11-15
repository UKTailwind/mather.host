' send-mail.bas: send an email through Gmail from a WebMite
' https://mather.host/blog/webmite-gmail/
' Needs a WiFi (WebMite) build of the PicoMite firmware, V6.04 or
' later, joined to your network with OPTION WIFI, and a Gmail app
' password.
Option Explicit

Const GmailUser = "your.name@gmail.com"   ' the Gmail account to send from
Const AppPassword = "abcdefghijklmnop"    ' its app password: 16 letters, no spaces
Const CRLF = Chr$(13) + Chr$(10)

Dim Integer rx(512)    ' Gmail's replies: a LONGSTRING of up to 4 KB
Dim Integer msg(512)   ' the outgoing message: a LONGSTRING of up to 4 KB

' Optional: check that the server really is Google (see the article)
' WEB NTP
' WEB TLS CA "gmail-ca.pem"

SendMail "someone@example.com", "Hello from the WebMite", "Sent by a Pico running MMBasic."
Print "Mail sent"
End

' Send a plain-text email. The body can be up to 255 characters.
Sub SendMail(mailto As String, subject As String, body As String)
  WEB OPEN TLS CLIENT "smtp.gmail.com", 465, 20000
  Pause 300
  Smtp "EHLO webmite", "250"
  Smtp "AUTH LOGIN", "334"
  Smtp B64(GmailUser), "334"
  Smtp B64(AppPassword), "235"
  Smtp "MAIL FROM:<" + GmailUser + ">", "250"
  Smtp "RCPT TO:<" + mailto + ">", "250"
  Smtp "DATA", "354"
  LongString Clear msg()
  LongString Append msg(), "From: " + GmailUser + CRLF
  LongString Append msg(), "To: " + mailto + CRLF
  LongString Append msg(), "Subject: " + subject + CRLF
  LongString Append msg(), CRLF
  LongString Append msg(), body + CRLF
  WEB TCP CLIENT WRITE msg()
  Smtp ".", "250"
  WEB CLOSE TCP CLIENT
End Sub

' Send one line to Gmail and check that the reply starts with the
' expected code. On any other reply, show it and stop.
Sub Smtp(cmd As String, code As String)
  WEB TCP CLIENT REQUEST cmd + CRLF, rx(), 20000
  If Replied(code) = 0 Then
    Print "Gmail replied: ";
    LongString Print rx()
    WEB CLOSE TCP CLIENT
    Error "Expected " + code
  EndIf
End Sub

' True if the last reply, or any line of it, starts with code
Function Replied(code As String) As Integer
  If LInStr(rx(), code) = 1 Then Replied = 1
  If LInStr(rx(), Chr$(10) + code) > 0 Then Replied = 1
End Function

' Base64-encode a string, as AUTH LOGIN needs
Function B64(s As String) As String
  Local Integer n = Math(BASE64 ENCODE s, B64)
End Function
