using System;
using System.Collections.Generic;
using System.Text;
using System.Windows.Media;

namespace HamQuestEngine
{
    public delegate void MessageQueueCallBack(string message,Color color);
    public class MessageQueue:GameClientBase
    {
        private event MessageQueueCallBack callBacks;
        private Queue<string> messages = new Queue<string>();
        private Queue<Color> colors = new Queue<Color>();
        private int maximumMessages = 0;
        public event MessageQueueCallBack CallBacks
        {
            add
            {
                callBacks += value;
            }
            remove
            {
                callBacks -= value;
            }
        }
        public void AddMessage(string message,params object[] theParams)
        {
            string colorName = GameConstants.Colors.Default;
            Descriptor messageDescriptor = Game.TableSet.MessageTable.GetMessageDescriptor(message);
            if (messageDescriptor != null)
            {
                colorName = messageDescriptor.GetProperty<string>(GameConstants.Properties.TextColor);
            }
            Color color = Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.ColorTable).GetProperty<Color>(colorName);
            colors.Enqueue(color);
            string translatedMessage = Game.TableSet.MessageTable.TranslateMessageText(message);
            if (theParams.Length > 0)
            {
                translatedMessage = string.Format(translatedMessage, theParams);
            }
            messages.Enqueue(translatedMessage);
            if (callBacks != null)
            {
                callBacks(message, color);
            }
            if (messages.Count > maximumMessages)
            {
                messages.Dequeue();
                colors.Dequeue();
            }
        }
        public Color[] Colors
        {
            get
            {
                return colors.ToArray();
            }
        }
        public string[] Messages
        {
            get
            {
                return (messages.ToArray());
            }
        }
        public MessageQueue(int theMaximumMessages,Game theGame):base(theGame)
        {
            maximumMessages = theMaximumMessages;
        }
    }
}
