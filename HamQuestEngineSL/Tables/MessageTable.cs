using System;
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Xml.Linq;
using System.Collections.Generic;

namespace HamQuestEngine
{
    public class MessageTable
    {
        private Dictionary<string, Descriptor> table = new Dictionary<string, Descriptor>();
        public Descriptor GetMessageDescriptor(string theMessageIdentifier)
        {
            Descriptor result = null;
            if (table.ContainsKey(theMessageIdentifier))
            {
                result = table[theMessageIdentifier];
            }
            return (result);
        }
        public MessageTable()
        {
            table.Clear();
            XDocument doc = XDocument.Load("config/messages.xml");
            foreach(XElement subElement in doc.Element("messages").Elements("message"))
            {
                string identifierString;
                PropertyValuePair[] properties = PropertyValuePair.LoadPropertyValuesFromXmlNode(subElement, out identifierString);
                table.Add(identifierString, new Descriptor(properties));
            }
        }
        public string TranslateMessageText(string message)
        {
            Descriptor messageDescriptor = GetMessageDescriptor(message);
            if (messageDescriptor != null)
            {
                if (messageDescriptor.HasProperty(GameConstants.Properties.Text))
                {
                    return messageDescriptor.GetProperty<string>(GameConstants.Properties.Text);
                }
                else
                {
                    return message;
                }
            }
            else
            {
                return message;
            }
        }
    }
}
