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
using PDGBoardGames;
using System.Collections.Generic;

namespace HamQuestEngine
{
    public class ShopInventoryEntry
    {
        private string itemIdentifier;
        private int numberInStock;
        private int numberInStockRoll;
        private int numberInStockDie;
        public string ItemIdentifier
        {
            get
            {
                return itemIdentifier;
            }
        }
        public int NumberInStock
        {
            get
            {
                return numberInStock;
            }
        }
        public int NumberInStockRoll
        {
            get
            {
                return numberInStockRoll;
            }
        }
        public int NumberInStockDie
        {
            get
            {
                return numberInStockDie;
            }
        }
        public int GenerateNumberInStock(IRandomNumberGenerator theRandomNumberGenerator)
        {
            int total = 0;
            for (int count = 0; count < NumberInStock; ++count)
            {
                if (theRandomNumberGenerator.Next(6) < numberInStockRoll)
                {
                    total++;
                }
            }
            return total;
        }
        private ShopInventoryEntry() { }
        public ShopInventoryEntry(string theItemIdentifier, int theNumberInStock, int thenumberInStockRoll)
        {
            itemIdentifier = theItemIdentifier;
            numberInStock = theNumberInStock;
            numberInStockRoll = thenumberInStockRoll;
        }
        public ShopInventoryEntry(XElement node)
        {
            foreach (XElement element in node.Elements())
            {
                if (element.Name == GameConstants.Properties.ItemIdentifier)
                {
                    itemIdentifier = element.Value;
                }
                else if (element.Name == GameConstants.Properties.NumberInStock)
                {
                    int.TryParse(element.Value, out numberInStock);
                }
                else if (element.Name == GameConstants.Properties.NumberInStockRoll)
                {
                    int.TryParse(element.Value, out numberInStockRoll);
                }
                else if (element.Name == GameConstants.Properties.NumberInStockDie)
                {
                    int.TryParse(element.Value, out numberInStockDie);
                }
            }
        }
        public static ShopInventoryEntry[] LoadFromNode(XElement node)
        {
            List<ShopInventoryEntry> entries = new List<ShopInventoryEntry>();
            for (XNode subNode = node.FirstNode; subNode != null; subNode = subNode.NextNode)
            {
                XElement element = subNode as XElement;
                if (element != null)
                {
                    entries.Add(new ShopInventoryEntry(element));
                }
            }
            return entries.ToArray();
        }
    }
}
