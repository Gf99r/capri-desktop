using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace CapriDesktop
{
    [DataContract]
    internal sealed class CodingAgentPayload
    {
        [DataMember(Name = "message")] internal string Message;
    }

    internal sealed class CodingAgentBridge : IDisposable
    {
        private readonly TcpListener listener;
        private readonly string token;
        private readonly Action<string> received;
        private readonly Thread worker;
        private readonly object gate = new object();
        private volatile bool stopped;
        private DateTime lastEvent = DateTime.MinValue;

        internal CodingAgentBridge(string token, Action<string> received)
        {
            this.token = token ?? "";
            this.received = received;
            int port;
            if (!int.TryParse(Environment.GetEnvironmentVariable("CAPRI_CORE_PORT"), out port) || port < 1 || port > 65535) port = 47824;
            listener = new TcpListener(IPAddress.Loopback, port);
            try
            {
                listener.Start(8);
                worker = new Thread(Listen);
                worker.IsBackground = true;
                worker.Name = "CAPRI coding-agent bridge";
                worker.Start();
            }
            catch (SocketException error)
            {
                Console.Error.WriteLine("CAPRI coding-agent bridge unavailable: " + error.Message);
                listener.Stop();
                stopped = true;
            }
        }

        private void Listen()
        {
            while (!stopped)
            {
                try
                {
                    using (TcpClient client = listener.AcceptTcpClient())
                    {
                        client.ReceiveTimeout = 3000;
                        client.SendTimeout = 3000;
                        Handle(client.GetStream());
                    }
                }
                catch (SocketException) { if (stopped) break; }
                catch (ObjectDisposedException) { break; }
                catch (IOException) { }
            }
        }

        private void Handle(NetworkStream stream)
        {
            try
            {
                string requestLine = ReadLine(stream, 2048);
                if (string.IsNullOrEmpty(requestLine)) { Respond(stream, 400); return; }
                string[] request = requestLine.Split(' ');
                if (request.Length < 2 || request[0] != "POST" || request[1] != "/event") { Respond(stream, 404); return; }

                Dictionary<string, string> headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                int headerBytes = 0;
                while (true)
                {
                    string line = ReadLine(stream, 8192);
                    if (line == null) { Respond(stream, 400); return; }
                    headerBytes += line.Length;
                    if (headerBytes > 8192) { Respond(stream, 413); return; }
                    if (line.Length == 0) break;
                    int colon = line.IndexOf(':');
                    if (colon > 0) headers[line.Substring(0, colon).Trim()] = line.Substring(colon + 1).Trim();
                }

                if (headers.ContainsKey("Origin")) { Respond(stream, 403); return; }
                string suppliedToken;
                if (!headers.TryGetValue("x-capri-token", out suppliedToken)) suppliedToken = "";
                byte[] supplied = Encoding.UTF8.GetBytes(suppliedToken);
                byte[] expected = Encoding.UTF8.GetBytes(token);
                if (expected.Length == 0 || !CryptographicOperations.FixedTimeEquals(supplied, expected)) { Respond(stream, 403); return; }

                int length;
                if (!headers.TryGetValue("Content-Length", out suppliedToken) || !int.TryParse(suppliedToken, out length) || length < 1 || length > 4096)
                {
                    Respond(stream, 413);
                    return;
                }

                byte[] json = new byte[length];
                int offset = 0;
                while (offset < length)
                {
                    int read = stream.Read(json, offset, length - offset);
                    if (read <= 0) { Respond(stream, 400); return; }
                    offset += read;
                }

                CodingAgentPayload payload;
                using (MemoryStream body = new MemoryStream(json))
                    payload = (CodingAgentPayload)new DataContractJsonSerializer(typeof(CodingAgentPayload)).ReadObject(body);

                string message = Safe(payload == null ? null : payload.Message);
                if (message.Length == 0) { Respond(stream, 400); return; }

                lock (gate)
                {
                    if (DateTime.UtcNow - lastEvent < TimeSpan.FromSeconds(2))
                    {
                        Respond(stream, 202);
                        return;
                    }
                    lastEvent = DateTime.UtcNow;
                }

                if (received != null) received(message);
                Respond(stream, 202);
            }
            catch (Exception error)
            {
                Console.Error.WriteLine("CAPRI coding-agent event rejected: " + error.Message);
                try { Respond(stream, 400); } catch (IOException) { }
            }
        }

        private static string ReadLine(Stream stream, int limit)
        {
            List<byte> bytes = new List<byte>();
            while (bytes.Count < limit)
            {
                int value = stream.ReadByte();
                if (value < 0) return bytes.Count == 0 ? null : Encoding.ASCII.GetString(bytes.ToArray());
                if (value == 10)
                {
                    if (bytes.Count > 0 && bytes[bytes.Count - 1] == 13) bytes.RemoveAt(bytes.Count - 1);
                    return Encoding.ASCII.GetString(bytes.ToArray());
                }
                bytes.Add((byte)value);
            }
            return null;
        }

        private static void Respond(NetworkStream stream, int status)
        {
            string reason = status == 202 ? "Accepted" : status == 403 ? "Forbidden" : status == 404 ? "Not Found" : status == 413 ? "Payload Too Large" : "Bad Request";
            byte[] response = Encoding.ASCII.GetBytes("HTTP/1.1 " + status + " " + reason + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
            stream.Write(response, 0, response.Length);
            stream.Flush();
        }

        private static string Safe(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "";
            StringBuilder clean = new StringBuilder();
            foreach (char c in value)
            {
                if (!char.IsControl(c)) clean.Append(c);
                if (clean.Length >= 150) break;
            }
            return clean.ToString().Trim();
        }

        public void Dispose()
        {
            if (stopped) return;
            stopped = true;
            listener.Stop();
            if (worker != null && worker != Thread.CurrentThread) worker.Join(500);
        }
    }
}
