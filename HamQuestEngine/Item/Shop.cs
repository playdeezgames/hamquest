using System;
using System.Collections.Generic;
using System.Text;
using System.Xml.Linq;
using PDGBoardGames;

namespace HamQuestEngine
{
    public class ShopState:GameClientBase
    {
        private string shopTitle = "";
        public string ShopTitle
        {
            get
            {
                return shopTitle;
            }
        }
        private PlayerDescriptor playerDescriptor;
        private CountedCollection<string> shopItems = new CountedCollection<string>();
        public CountedCollection<string> ShopItems
        {
            get
            {
                return shopItems;
            }
        }
        private List<string> itemList = new List<string>();
        public List<string> ItemList
        {
            get
            {
                return itemList;
            }
        }
        public bool CanBuyOne(string identifier)
        {
            Descriptor descriptor = Game.TableSet.ItemTable.GetItemDescriptor(identifier);
            return (ShopItems[identifier] > 0) && (playerDescriptor.Money >= descriptor.GetProperty<int>(GameConstants.Properties.Price));
        }
        public bool CanBuyAll(string identifier)
        {
            Descriptor descriptor = Game.TableSet.ItemTable.GetItemDescriptor(identifier);
            return (ShopItems[identifier] > 0) && (playerDescriptor.Money >= descriptor.GetProperty<int>(GameConstants.Properties.Price) * ShopItems[identifier]);
        }
        public bool BuyOne(string identifier)
        {
            if (!CanBuyOne(identifier)) return false;
            Descriptor descriptor = Game.TableSet.ItemTable.GetItemDescriptor(identifier);
            playerDescriptor.AddItem(identifier);
            ShopItems.Remove(identifier);
            playerDescriptor.Money -= descriptor.GetProperty<uint>(GameConstants.Properties.Price);
            return true;
        }
        public bool BuyAll(string identifier)
        {
            if (!CanBuyAll(identifier)) return false;
            Descriptor descriptor = Game.TableSet.ItemTable.GetItemDescriptor(identifier);
            uint count = ShopItems[identifier];
            playerDescriptor.Money -= descriptor.GetProperty<uint>(GameConstants.Properties.Price) * count;
            ShopItems.Remove(identifier, count);
            while (count > 0)
            {
                playerDescriptor.AddItem(identifier);
                count--;
            }
            return true;
        }
        private int itemIndex = 0;
        public int ItemIndex
        {
            get
            {
                return itemIndex;
            }
            set
            {
                if (value >= 0 && value < itemList.Count)
                {
                    itemIndex = value;
                }
            }
        }
        public ShopState(Descriptor shopDescriptor, PlayerDescriptor thePlayerDescriptor,Game theGame):base(theGame)
        {
            shopTitle = Game.TableSet.MessageTable.TranslateMessageText(shopDescriptor.GetProperty<string>(GameConstants.Properties.ShopTitle));
            playerDescriptor = thePlayerDescriptor;
            foreach (ShopInventoryEntry entry in shopDescriptor.GetProperty<ShopInventoryEntry[]>(GameConstants.Properties.Inventory))
            {
                for (int index = 0; index < entry.NumberInStock; ++index)
                {
                    if (Game.RandomNumberGenerator.Next(entry.NumberInStockDie) < entry.NumberInStockRoll)
                    {
                        shopItems.Add(entry.ItemIdentifier);
                        if (!itemList.Contains(entry.ItemIdentifier))
                        {
                            itemList.Add(entry.ItemIdentifier);
                        }
                    }
                }
            }
        }
    }
}
