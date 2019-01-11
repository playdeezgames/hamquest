using System;
using System.Net;
using System.Windows;
using System.Windows.Input;

namespace HamQuestEngine
{
    public class TableSet
    {
        private CreatureTable creatureTable;
        public CreatureTable CreatureTable
        {
            get
            {
                return creatureTable;
            }
        }
        private MessageTable messageTable;
        public MessageTable MessageTable
        {
            get
            {
                return messageTable;
            }
        }
        private PropertyGroupTable propertyGroupTable;
        public PropertyGroupTable PropertyGroupTable
        {
            get
            {
                return propertyGroupTable;
            }
        }
        private TerrainTable terrainTable;
        public TerrainTable TerrainTable
        {
            get
            {
                return terrainTable;
            }
        }
        private ItemTable itemTable;
        public ItemTable ItemTable
        {
            get
            {
                return itemTable;
            }
        }
        public TableSet(CreatureTable theCreatureTable,MessageTable theMessageTable,PropertyGroupTable thePropertyGroupTable,TerrainTable theTerrainTable,ItemTable theItemTable)
        {
            creatureTable = theCreatureTable;
            messageTable = theMessageTable;
            propertyGroupTable = thePropertyGroupTable;
            terrainTable = theTerrainTable;
            itemTable = theItemTable;
        }
    }
}
