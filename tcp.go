package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"log"
	"time"
	"os"
)

// 自定义协议的组包和拆包
type Packet struct {
	Version [2]byte
	Length int16
	Data    []byte
}

func (p *Packet) String() string {
	return fmt.Sprintf("Version: %v Length: %d Data: %s",
		string(p.Version[:]), p.Length, string(p.Data))
}

func (p *Packet) Pack(w io.Writer) {
	binary.Write(w, binary.BigEndian, p.Version)
	binary.Write(w, binary.BigEndian, p.Length)
	binary.Write(w, binary.BigEndian, p.Data)
}

func (p *Packet) Unpack(r io.Reader) {
	binary.Read(r, binary.BigEndian, &p.Version)
	binary.Read(r, binary.BigEndian, &p.Length)
	if p.Length > 0 {
		p.Data = make([]byte, p.Length)
	}
	binary.Read(r, binary.BigEndian, &p.Data)
}

func main() {
	go startServer()
	//time.Sleep(time.Second * 5)
	//connection()
	select { }
}

func startServer()  {

	listen, err := net.Listen("tcp", ":8800")
	if err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
	defer listen.Close()
	for {
		conn, err := listen.Accept()
		if err != nil {
			fmt.Println("Accept error: ", err)
			continue
		}
		go handleConn(conn)
	}
}

func connection()  {
	conn, err := net.Dial("tcp", "127.0.0.1:8800")
	if err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
	fmt.Println("connection successful...")
	defer  conn.Close()
	ticker := time.NewTicker(time.Second * 5)
	idx := 0
	for range ticker.C {
		fmt.Println("send....")
		idx += 1
		var packet Packet
		packet.Version[0] = 'V'
		packet.Version[1] = '1'
		packet.Data = []byte(("index: " + fmt.Sprintf("%d ", idx) + "现在时间是:" + time.Now().Format("2006-01-02 15:04:05")))
		packet.Length = int16(len(packet.Data))
		buf := new(bytes.Buffer)
		packet.Pack(buf)
		packet.Pack(buf)
		packet.Pack(buf)
		length, err := conn.Write(buf.Bytes())
		if err != nil {
			fmt.Println("conn write error:", err)
			continue
		} else {
			fmt.Println("conn write successful length:", length)
		}
		buf = new(bytes.Buffer)
		packet.Pack(buf)
		packet.Pack(buf)
		packet.Pack(buf)
		length, err = conn.Write(buf.Bytes())
		if err != nil {
			fmt.Println("conn write error:", err)
		} else {
			fmt.Println("conn write successful length:", length)
		}

	}
}

func handleConn(conn net.Conn) {
	fmt.Println(conn.RemoteAddr().String() + " 连接")
	defer func() {
		conn.Close()
		fmt.Println(conn.RemoteAddr().String() + " 断开")
	}()

	go func() {
		for {
			var packet Packet
			packet.Version[0] = 'V'
			packet.Version[1] = '1'
			packet.Data = []byte("现在时间是:" + time.Now().Format("2006-01-02 15:04:05"))
			//packet.Data = []byte("hello")
			packet.Length = int16(len(packet.Data))
			buf := new(bytes.Buffer)
			packet.Pack(buf)
			if _, err := conn.Write(buf.Bytes()); err != nil {
				return
			}
			fmt.Println(conn.RemoteAddr().String() + "  ", packet.String())
			fmt.Println(conn.RemoteAddr().String() + "  " + string(buf.Bytes()))
			time.Sleep(time.Second * 2)
		}
	}()
	// 创建Scanner，分析buf数据流(r io.Reader，换成net.Conn对象就是处理tcp数据流，自己连数据都不需要去收取)
	scanner := bufio.NewScanner(conn)
	// 数据的分离规则，根据协议自定义
	split := func(data []byte, atEOF bool) (advance int, token []byte, err error) {
		if !atEOF && data[0] == 'V' {
			if len(data) > 4 {
				var dataLen int16
				binary.Read(bytes.NewReader(data[2:4]), binary.BigEndian, &dataLen)
				if int(dataLen)+4 <= len(data) {
					return int(dataLen) + 4, data[:int(dataLen)+4], nil
				}
			}
		}
		return
	}
	// 设置分离函数
	scanner.Split(split)
	// 获取分离出来的数据
	for scanner.Scan() {
		pac := new(Packet)
		pac.Unpack(bytes.NewReader(scanner.Bytes()))
		fmt.Println(pac)
	}
	if err := scanner.Err(); err != nil {
		fmt.Printf("Invalid input: %s", err)
	}
}