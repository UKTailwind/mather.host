' send-attachment.bas: email a file through Gmail from a WebMite
' https://mather.host/blog/webmite-gmail/
' Needs a WiFi (WebMite) build of the PicoMite firmware, V6.04 or
' later, joined to your network with OPTION WIFI, and a Gmail app
' password.
Option Explicit

Const GmailUser = "your.name@gmail.com"   ' the Gmail account to send from
Const AppPassword = "abcdefghijklmnop"    ' its app password: 16 letters, no spaces
Const CRLF = Chr$(13) + Chr$(10)
Const Q = Chr$(34)                        ' a double quote
Const Boundary = "WebMite-boundary-7d3f9a"  ' separates the parts of the message

Dim Integer rx(512)    ' Gmail's replies: a LONGSTRING of up to 4 KB
Dim Integer msg(512)   ' the outgoing message, sent in blocks of up to 4 KB

' Optional: check that the server really is Google (see the article)
' WEB NTP
' WEB TLS CA "gmail-ca.pem"

SendFile "someone@example.com", "Today's log", "The log file is attached.", "log.csv", "text/csv"
Print "Mail sent"
End

' Send a plain-text email with one file attached. fname can include a
' drive and folder, eg "B:/logs/today.csv". ftype is the file's MIME
' type, eg "text/csv", "image/jpeg" or "application/octet-stream".
Sub SendFile(mailto As String, subject As String, body As String, fname As String, ftype As String)
  Local String chunk, coded, shown
  Local Integer i, n

  ' The name shown in the email: fname without its drive or folder
  shown = fname
  For i = Len(fname) To 1 Step -1
    If Mid$(fname, i, 1) = "/" Or Mid$(fname, i, 1) = ":" Then
      shown = Mid$(fname, i + 1)
      Exit For
    EndIf
  Next i

  WEB OPEN TLS CLIENT "smtp.gmail.com", 465, 20000
  Pause 300
  Smtp "EHLO webmite", "250"
  Smtp "AUTH LOGIN", "334"
  Smtp B64(GmailUser), "334"
  Smtp B64(AppPassword), "235"
  Smtp "MAIL FROM:<" + GmailUser + ">", "250"
  Smtp "RCPT TO:<" + mailto + ">", "250"
  Smtp "DATA", "354"

  ' The headers, then the text part of the message
  LongString Clear msg()
  LongString Append msg(), "From: " + GmailUser + CRLF
  LongString Append msg(), "To: " + mailto + CRLF
  LongString Append msg(), "Subject: " + subject + CRLF
  LongString Append msg(), "MIME-Version: 1.0" + CRLF
  LongString Append msg(), "Content-Type: multipart/mixed; boundary=" + Q + Boundary + Q + CRLF
  LongString Append msg(), CRLF
  LongString Append msg(), "--" + Boundary + CRLF
  LongString Append msg(), "Content-Type: text/plain; charset=UTF-8" + CRLF
  LongString Append msg(), CRLF
  LongString Append msg(), body + CRLF

  ' The attachment's own headers
  LongString Append msg(), "--" + Boundary + CRLF
  LongString Append msg(), "Content-Type: " + ftype + "; name=" + Q + shown + Q + CRLF
  LongString Append msg(), "Content-Transfer-Encoding: base64" + CRLF
  LongString Append msg(), "Content-Disposition: attachment; filename=" + Q + shown + Q + CRLF
  LongString Append msg(), CRLF

  ' The file: every 57 bytes become one 76-character line of base64,
  ' and each block is sent as soon as it holds about 4 KB
  Open fname For Input As #1
  Do While Not Eof(#1)
    chunk = Input$(57, #1)
    n = Math(BASE64 ENCODE chunk, coded)
    LongString Append msg(), coded + CRLF
    If LLen(msg()) > 4000 Then
      WEB TCP CLIENT WRITE msg()
      LongString Clear msg()
    EndIf
  Loop
  Close #1

  ' Close the last part, send what is left, then end the message
  LongString Append msg(), "--" + Boundary + "--" + CRLF
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
