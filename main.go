package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	gomail "gopkg.in/gomail.v2"
)

// enviar-email -para alema5@gmail.com -asunto "test" -mensaje "boom" -adjuntos log1,log2

var (
	body       string
	recipient  string
	subject    string
	attachment string
	from       string
)

const (
	server = "smtp.gmail.com"
	port   = 587
)

func init() {
	flag.StringVar(&from, "de", "", "Email del remitente")
	flag.StringVar(&subject, "asunto", "", "Asunto del mensaje")
	flag.StringVar(&body, "mensaje", "", "Cuerpo del mensaje")
	flag.StringVar(&recipient, "para", "", "Correos destinatarios. Separados por coma.")
	flag.StringVar(&attachment, "adjuntos", "", "Archivos adjuntos. Separados por coma.")
}

func main() {
	flag.Parse()

	if recipient == "" || body == "" || subject == "" {
		flag.Usage()
		os.Exit(1)
	}

	if from == "" {
		from = "alema5@gmail.com"
	}

	recipients := strings.Split(recipient, ",")
	attachments := strings.Split(attachment, ",")

	send(subject, body, recipients, attachments)
}

func send(subject, body string, recipients, attachments []string) {
	username, password := os.Getenv("USERNAME"), os.Getenv("PASSWORD")

	m := gomail.NewMessage()
	m.SetHeader("From", from)
	m.SetHeader("To", recipients...)
	m.SetHeader("Subject", subject)
	m.SetBody("text/html", body)

	for _, a := range attachments {
		if a != "" {
			m.Attach(a)
		}
	}

	d := gomail.NewDialer(server, port, username, password)
	if err := d.DialAndSend(m); err != nil {
		panic(err)
	}

	fmt.Printf("Email enviado exitosamente a %s!", recipients)
}
