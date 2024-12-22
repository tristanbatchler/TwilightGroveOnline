package states

import (
	"fmt"
	"log"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type Admin struct {
	client  central.ClientInterfacer
	queries *db.Queries
	logger  *log.Logger
}

func (a *Admin) Name() string {
	return "Admin"
}

func (a *Admin) SetClient(client central.ClientInterfacer) {
	a.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), a.Name())
	a.queries = client.DbTx().Queries
	a.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (a *Admin) OnEnter() {
}

func (a *Admin) HandleMessage(senderId uint64, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_SqlQuery:
		a.handleSqlQuery(senderId, message)
	}
}

func (a *Admin) handleSqlQuery(senderId uint64, message *packets.Packet_SqlQuery) {
	if senderId != a.client.Id() {
		a.logger.Printf("Received request to run SQL query from another client (%d)", senderId)
		return
	}

	rows, err := a.client.RunSql(message.SqlQuery.Query)
	if err != nil {
		a.logger.Printf("Error running SQL query: %v", err)
		a.client.SocketSend(packets.NewSqlResponse(false, err, nil, nil))
		return
	}

	columns, err := rows.Columns()
	if err != nil {
		a.logger.Printf("Error getting column names: %v", err)
		a.client.SocketSend(packets.NewSqlResponse(false, err, nil, nil))
		return
	}

	rowMessages := make([]*packets.SqlRow, 0)
	for rows.Next() {
		row := make([]interface{}, len(columns))
		for i := range row {
			row[i] = new(interface{})
		}

		err = rows.Scan(row...)
		if err != nil {
			a.logger.Printf("Error scanning row: %v", err)
			a.client.SocketSend(packets.NewSqlResponse(false, err, nil, nil))
			return
		}

		rowMessage := &packets.SqlRow{
			Values: make([]string, len(columns)),
		}

		for i := range row {
			rowMessage.Values[i] = fmt.Sprintf("%v", *row[i].(*interface{}))
		}

		rowMessages = append(rowMessages, rowMessage)
	}

	a.client.SocketSend(packets.NewSqlResponse(true, nil, columns, rowMessages))
}

func (a *Admin) OnExit() {
}
