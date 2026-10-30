using System;
using System.IO;
using System.Net;
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
        private readonly HttpListener listener = new HttpListener();
        private readonly string token;
        private readonly Action<string> received;
        private readonly Thread worker;
        private volatile bool stopped;
        private DateTime lastEvent = DateTime.MinValue;

        internal CodingAgentBridge(string token, Action<string> received)
        {
            this.token = token ?? "";
            this.received = received;
            int port = 47824;
            int.TryParse(Environment.GetEnvironmentVariable("CAPRI_CORE_PORT"), out port);
            if (port < 1 || port > 65535) port = 47824;
            listener.Prefixes.Add("http://127.0.0.1:" + port + "/");
            try
            {
                listener.Start();
                worker = new Thread(Listen);
                worker.IsBackground = true;
                worker.Name = "CAPRI coding-agent bridge";
                worker.Start();
            }
            catch (HttpListenerException error)
            {
                Console.Error.WriteLine("CAPRI coding-agent bridge unavailable: " + error.Message);
                listener.Close();
                stopped = true;
            }
        }

        private void Listen()
        {
            while (!stopped)
            {
                HttpListenerContext context = null;
                try { context = listener.GetContext(); }
                catch (HttpListenerException) { if (stopped) break; }
                catch (ObjectDisposedException) { break; }
                if (context != null) ThreadPool.QueueUserWorkItem(delegate { Handle(context); });
            }
        }

        private void Handle(HttpListenerContext context)
        {
            try
            {
                HttpListenerRequest request = context.Request;
                if (request.HttpMethod != "POST" || request.Url.AbsolutePath != "/event" ||
                    !string.IsNullOrEmpty(request.Headers["Origin"]))
                {
                    context.Response.StatusCode = 404;
                    return;
                }

                byte[] supplied = Encoding.UTF8.GetBytes(request.Headers["x-capri-token"] ?? "");
                byte[] expected = Encoding.UTF8.GetBytes(token);
                if (expected.Length == 0 || !CryptographicOperations.FixedTimeEquals(supplied, expected))
                {
                    context.Response.StatusCode = 403;
                    return;
                }

                if (request.ContentLength64 < 1 || request.ContentLength64 > 4096)
                {
                    context.Response.StatusCode = 413;
                    return;
                }

                CodingAgentPayload payload;
                using (MemoryStream body = new MemoryStream())
                {
                    byte[] buffer = new byte[1024];
                    int read;
                    while ((read = request.InputStream.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        if (body.Length + read > 4096) { context.Response.StatusCode = 413; return; }
                        body.Write(buffer, 0, read);
                    }
                    body.Position = 0;
                    payload = (CodingAgentPayload)new DataContractJsonSerializer(typeof(CodingAgentPayload)).ReadObject(body);
                }

                string message = Safe(payload == null ? null : payload.Message);
                if (message.Length == 0) { context.Response.StatusCode = 400; return; }

                lock (this)
                {
                    if (DateTime.UtcNow - lastEvent < TimeSpan.FromSeconds(2))
                    {
                        context.Response.StatusCode = 202;
                        return;
                    }
                    lastEvent = DateTime.UtcNow;
                }

                if (received != null) received(message);
                context.Response.StatusCode = 202;
            }
            catch (Exception error)
            {
                Console.Error.WriteLine("CAPRI coding-agent event rejected: " + error.Message);
                try { context.Response.StatusCode = 400; } catch (ObjectDisposedException) { }
            }
            finally
            {
                try { context.Response.Close(); } catch (ObjectDisposedException) { }
            }
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
            try { listener.Stop(); } catch (ObjectDisposedException) { }
            try { listener.Close(); } catch (ObjectDisposedException) { }
            if (worker != null && worker != Thread.CurrentThread) worker.Join(500);
        }
    }
}
