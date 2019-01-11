using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;
using PDGBoardGames;

using System.Xml.Linq;
using System.Diagnostics;
using System.Windows.Input;
using System.Drawing;
using System.Windows.Media;


namespace HamQuestEngine
{
    public class PlayerDescriptor : Descriptor
    {
        #region Private Fields
        private string _playerState = GameConstants.PlayerStates.Play;
        private string _weapon = String.Empty;
        private Dictionary<string, string> _armors = new Dictionary<string, string>();
        private CountedCollection<string> _items = new CountedCollection<string>();
        #endregion

        #region Public Properties
        public IEnumerable<string> ItemIdentifiers
        {
            get
            {
                return _items.Values;
            }
        }
        public Maze Maze { get; set; }
        public ShopState ShopState { get; set; }
        public int ExperiencePoints { get; set; }
        public int ExperienceGoal { get; set; }
        public int ExperienceLevel { get; set; }
        public Creature MapCreature { get; set; }
        public int MazeColumn { get; set; }
        public int MazeRow { get; set; }
        public MessageQueue MessageQueue
        {
            get
            {
                return Maze.Game.MessageQueue;
            }
        }
        public uint QuestItems
        {
            get
            {
                return _items[GetProperty<string>(GameConstants.Properties.QuestItemName)];
            }
            set
            {
                string theQuestItemName = GetProperty<string>(GameConstants.Properties.QuestItemName);
                if (_items[theQuestItemName] > value)
                {
                    _items.Remove(theQuestItemName, _items[theQuestItemName] - value);
                }
                else if (_items[theQuestItemName] < value)
                {
                    _items.Add(theQuestItemName, value - _items[theQuestItemName]);
                }
            }
        }
        public string LightSource
        {
            get
            {
                int level = -1;
                string result = String.Empty;
                foreach (string itemIdentifier in _items.Values)
                {
                    Descriptor itemDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                    if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Light)
                    {
                        if (itemDescriptor.GetProperty<int>(GameConstants.Properties.LightLevel) > level)
                        {
                            level = itemDescriptor.GetProperty<int>(GameConstants.Properties.LightLevel);
                            result = itemIdentifier;
                        }
                    }
                }
                return (result);
            }
        }
        public uint Money
        {
            get
            {

                return _items[Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.PlayerConstants).GetProperty<string>(GameConstants.Properties.CurrencyItemIdentifier)];
            }
            set
            {
                _items.Remove(Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.PlayerConstants).GetProperty<string>(GameConstants.Properties.CurrencyItemIdentifier), Money);
                _items.Add(Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.PlayerConstants).GetProperty<string>(GameConstants.Properties.CurrencyItemIdentifier), value);
            }
        }
        #endregion

        #region Private Methods
        private void messageQueueCallback(string message, Color color)
        {
            GetProperty<PlayerMessageStatistics>(GameConstants.Properties.MessageStatistics).AddEntry(message);
        }
        private void AddItemDurability(string itemIdentifier)
        {
            Descriptor descriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
            if ((descriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Weapon) || (descriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Armor))
            {
                CountedCollection<string> durabilities = GetProperty<CountedCollection<string>>(GameConstants.Properties.ItemDurabilities);
                if (!durabilities.Has(itemIdentifier))
                {
                    durabilities.Add(itemIdentifier, (uint)descriptor.GetProperty<int>(GameConstants.Properties.Durability));
                }
                else
                {
                    durabilities[itemIdentifier] += (uint)descriptor.GetProperty<int>(GameConstants.Properties.Durability);
                }
            }
        }
        private void AutoEquipArmors()
        {
            bool twoHandedWeapon = false;
            if (_weapon != String.Empty)
            {
                twoHandedWeapon = (Maze.Game.TableSet.ItemTable.GetItemDescriptor(_weapon)).GetProperty<bool>(GameConstants.Properties.TwoHanded);
            }
            foreach (string itemIdentifier in _items.Values)
            {
                Descriptor newArmorDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                if (newArmorDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Armor)
                {
                    string armorType = newArmorDescriptor.GetProperty<string>(GameConstants.Properties.ArmorType);
                    if (armorType != GameConstants.ArmorTypes.Shield || !twoHandedWeapon)
                    {
                        if (_armors[armorType] == String.Empty)
                        {
                            _armors[armorType] = itemIdentifier;
                        }
                        else
                        {
                            Descriptor currentArmorDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(_armors[armorType]);
                            string newGeneratorName = newArmorDescriptor.GetProperty<string>(GameConstants.Properties.DefendGenerator);
                            string currentGeneratorName = currentArmorDescriptor.GetProperty<string>(GameConstants.Properties.DefendGenerator);
                            WeightedGenerator<int> newGenerator = Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(newGeneratorName);
                            WeightedGenerator<int> currentGenerator = Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(currentGeneratorName);
                            if (newGenerator.MaximalValue > currentGenerator.MaximalValue)
                            {
                                _armors[armorType] = itemIdentifier;
                            }
                        }
                    }
                }
            }
        }
        private void AutoEquipWeapon()
        {
            Descriptor currentWeaponDescriptor = null;
            foreach (string itemIdentifier in _items.Values)
            {
                Descriptor newWeaponDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                if (newWeaponDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Weapon)
                {
                    if (!newWeaponDescriptor.GetProperty<bool>(GameConstants.Properties.TwoHanded) || _armors[GameConstants.ArmorTypes.Shield] == String.Empty)
                    {
                        if (currentWeaponDescriptor == null)
                        {
                            _weapon = itemIdentifier;
                            currentWeaponDescriptor = newWeaponDescriptor;
                        }
                        else if (newWeaponDescriptor.GetProperty<int>(GameConstants.Properties.AttackValue) > currentWeaponDescriptor.GetProperty<int>(GameConstants.Properties.AttackValue))
                        {
                            _weapon = itemIdentifier;
                            currentWeaponDescriptor = newWeaponDescriptor;
                        }
                    }
                }
            }
        }
        private void rollSpeed()
        {
            if (Maze == null) return;
            int speed = GetProperty<WeightedGenerator<int>>(GameConstants.Properties.SpeedRoll).Generate(Maze.Game.RandomNumberGenerator);
            float multiplier = 1.0f;
            foreach (string itemIdentifier in _armors.Values)
            {
                if (itemIdentifier != String.Empty)
                {
                    Descriptor armorDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                    multiplier *= armorDescriptor.GetProperty<float>(GameConstants.Properties.SpeedMultiplier);
                }
            }
            speed = (int)((float)speed * multiplier);
            if (speed == 0) speed = 1;
            GetProperty<PlayerStepTracker>(GameConstants.Properties.StepTracker).Reset(speed);
        }
        private void decrementLightSource()
        {
            string lightSource = LightSource;
            if (lightSource != String.Empty)
            {
                Descriptor itemDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(lightSource);
                if (itemDescriptor.GetProperty<int>(GameConstants.Properties.Duration) == 0) return;

                CountedCollection<string> durabilities = GetProperty<CountedCollection<string>>(GameConstants.Properties.ItemDurabilities);
                durabilities[lightSource]--;
                if (durabilities[lightSource] % (uint)itemDescriptor.GetProperty<int>(GameConstants.Properties.Duration) == 0)
                {
                    MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.GoOutMessage));
                    _items.Remove(lightSource);
                }
            }
        }
        #endregion

        #region Protected Methods
        protected int getHealth()
        {
            return ExperienceLevel + GetProperty<int>(GameConstants.Properties.InitialHealth);
        }
        protected int getAttack()
        {
            int result = 0;
            if (_weapon != String.Empty)
            {
                Descriptor weaponDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(_weapon);
                result += weaponDescriptor.GetProperty<int>(GameConstants.Properties.AttackValue);
            }
            return (result);
        }
        protected int getSpeed()
        {
            return GetProperty<PlayerStepTracker>(GameConstants.Properties.StepTracker).Total;
        }
        #endregion

        #region Public Methods
        public void AddExperience(int experiencePoints)
        {
            if (experiencePoints == 1)
            {
                MessageQueue.AddMessage(string.Format(GetProperty<string>(GameConstants.Properties.GainExperiencePointMessage), experiencePoints) , experiencePoints);
            }
            else
            {
                MessageQueue.AddMessage(string.Format(GetProperty<string>(GameConstants.Properties.GainExperiencePointsMessage), experiencePoints) , experiencePoints);
            }
            ExperiencePoints += experiencePoints;
            if (ExperiencePoints >= ExperienceGoal)
            {
                MessageQueue.AddMessage(GetProperty<string>(GameConstants.Properties.GainExperienceLevelMessage));
                ExperiencePoints -= ExperienceGoal;
                ExperienceGoal *= GetProperty<int>(GameConstants.Properties.ExeperienceGoalMultiplier);
                ExperienceGoal /= GetProperty<int>(GameConstants.Properties.ExeperienceGoalDivisor);
                MapCreature.Wounds = 0;
                ExperienceLevel++;
            }
        }
        public void TakeDamage(int damage, int defendRoll)
        {
            MapCreature.Wounds += damage;
            MapCreature.BeenHit = true;
            CheckForArmorBreakage(defendRoll);
            while (MapCreature.Dead)
            {
                bool found = false;
                foreach (string identifier in _items.Values)
                {
                    Descriptor descriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(identifier);
                    if (descriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Healing && descriptor.GetProperty<string>(GameConstants.Properties.HealingType) == GameConstants.HealingTypes.Save)
                    {
                        MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.UseMessage));
                        MapCreature.Wounds -= descriptor.GetProperty<int>(GameConstants.Properties.HealingAmount);
                        _items.Remove(identifier);
                        found = true;
                        break;
                    }
                }
                if (!found)
                {
                    _playerState = HamQuestEngine.GameConstants.PlayerStates.Lose;
                    MessageQueue.AddMessage(GetProperty<string>(GameConstants.Properties.KilledMessage));
                    return;
                }
            }
        }
        public void EatIfNeeded()
        {
            while (MapCreature.Wounds > 0)
            {
                bool found = false;
                foreach (string identifier in _items.Values)
                {
                    Descriptor descriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(identifier);
                    if (descriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Healing && descriptor.GetProperty<string>(GameConstants.Properties.HealingType) == GameConstants.HealingTypes.Eaten)
                    {
                        MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.UseMessage));
                        MapCreature.Wounds -= descriptor.GetProperty<int>(GameConstants.Properties.HealingAmount);
                        _items.Remove(identifier);
                        found = true;
                        break;
                    }
                }
                if (!found) return;
            }
        }
        public void UpdatePathfinding()
        {
            Map theMap = MapCreature.Map;
            int column;
            int row;
            int direction;
            int nextColumn;
            int nextRow;
            Queue<int> columns = new Queue<int>();
            Queue<int> rows = new Queue<int>();
            Directions directions = new Directions();
            int lowestValue;
            for (column = 0; column < theMap.Columns; ++column)
            {
                for (row = 0; row < theMap.Rows; ++row)
                {
                    theMap[column][row].PathfindingValue = int.MaxValue;
                }
            }
            column = MapCreature.Column;
            row = MapCreature.Row;
            theMap[column][row].PathfindingValue = 0;
            for (direction = 0; direction < directions.Count; ++direction)
            {
                nextColumn = directions.GetNextColumn(column, row, direction);
                nextRow = directions.GetNextRow(column, row, direction);
                if (nextColumn < 0) continue;
                if (nextRow < 0) continue;
                if (nextColumn >= theMap.Columns) continue;
                if (nextRow >= theMap.Rows) continue;
                if (theMap[nextColumn][nextRow].PathfindingValue != int.MaxValue) continue;
                if (theMap[nextColumn][nextRow].ItemIdentifier != String.Empty) continue;
                if (!Maze.Game.TableSet.TerrainTable.GetTerrainDescriptor(theMap[nextColumn][nextRow].TerrainIdentifier).GetProperty<bool>(GameConstants.Properties.Passable)) continue;
                columns.Enqueue(nextColumn);
                rows.Enqueue(nextRow);
            }
            while (columns.Count > 0)
            {
                column = columns.Dequeue();
                row = rows.Dequeue();
                if (theMap[column][row].PathfindingValue != int.MaxValue) continue;
                lowestValue = int.MaxValue;
                for (direction = 0; direction < directions.Count; ++direction)
                {
                    nextColumn = directions.GetNextColumn(column, row, direction);
                    nextRow = directions.GetNextRow(column, row, direction);
                    if (nextColumn < 0) continue;
                    if (nextRow < 0) continue;
                    if (nextColumn >= theMap.Columns) continue;
                    if (nextRow >= theMap.Rows) continue;
                    if (theMap[nextColumn][nextRow].PathfindingValue < lowestValue)
                    {
                        lowestValue = theMap[nextColumn][nextRow].PathfindingValue;
                    }
                }
                theMap[column][row].PathfindingValue = lowestValue + 1;
                for (direction = 0; direction < directions.Count; ++direction)
                {
                    nextColumn = directions.GetNextColumn(column, row, direction);
                    nextRow = directions.GetNextRow(column, row, direction);
                    if (nextColumn < 0) continue;
                    if (nextRow < 0) continue;
                    if (nextColumn >= theMap.Columns) continue;
                    if (nextRow >= theMap.Rows) continue;
                    if (theMap[nextColumn][nextRow].PathfindingValue != int.MaxValue) continue;
                    if (theMap[nextColumn][nextRow].ItemIdentifier != String.Empty) continue;
                    if (!Maze.Game.TableSet.TerrainTable.GetTerrainDescriptor(theMap[nextColumn][nextRow].TerrainIdentifier).GetProperty<bool>(GameConstants.Properties.Passable)) continue;
                    columns.Enqueue(nextColumn);
                    rows.Enqueue(nextRow);
                }
            }
        }
        public void RevealTraps()
        {
            Directions directions = new Directions();
            for (int direction = 0; direction < directions.Count; ++direction)
            {
                MapCreature.Map.RevealHiddens(directions.GetNextColumn(MapCreature.Column, MapCreature.Row, direction), directions.GetNextRow(MapCreature.Column, MapCreature.Row, direction));
            }
        }
        public bool IsEquipped(string itemIdentifier)
        {
            if (itemIdentifier == String.Empty) return (false);
            if (itemIdentifier == _weapon) return (true);
            if (itemIdentifier == LightSource) return (true);
            if (_armors.ContainsValue(itemIdentifier)) return (true);
            return (false);
        }
        public void CheckForWeaponBreakage(int damage)
        {
            if (_weapon != String.Empty)
            {
                Descriptor weaponDescriptor = (Maze.Game.TableSet.ItemTable.GetItemDescriptor(_weapon));
                CountedCollection<string> durabilities = GetProperty<CountedCollection<string>>(GameConstants.Properties.ItemDurabilities);
                if (damage > durabilities[_weapon])
                {
                    durabilities[_weapon] = 0;
                }
                else
                {
                    durabilities[_weapon] -= (uint)damage;
                }
                if (((durabilities[_weapon] + weaponDescriptor.GetProperty<int>(GameConstants.Properties.Durability) - 1) / weaponDescriptor.GetProperty<int>(GameConstants.Properties.Durability)) < _items[_weapon])
                {
                    MessageQueue.AddMessage(weaponDescriptor.GetProperty<string>(GameConstants.Properties.BrokenMessage));
                    _items.Remove(_weapon);
                    AutoEquip();
                }
            }
        }
        public void CheckForArmorBreakage(int damage)
        {
            if (damage <= 0) return;
            List<string> brokenList = new List<string>();
            List<string> wornList = new List<string>();
            foreach (string itemIdentifier in _armors.Values)
            {
                if (itemIdentifier != String.Empty)
                {
                    if (Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier).HasTag(GameConstants.Tags.Durable))
                    {
                        wornList.Add(itemIdentifier);
                    }
                }
            }
            while ((damage > 0) && (wornList.Count > 0))
            {
                string itemIdentifier = wornList[Maze.Game.RandomNumberGenerator.Next(wornList.Count)];
                CountedCollection<string> durabilities = GetProperty<CountedCollection<string>>(GameConstants.Properties.ItemDurabilities);
                if (durabilities[itemIdentifier] > 0)
                {
                    durabilities[itemIdentifier]--;
                    damage--;
                }
                Descriptor armorDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                if (((durabilities[itemIdentifier] + armorDescriptor.GetProperty<int>(GameConstants.Properties.Durability) - 1) / armorDescriptor.GetProperty<int>(GameConstants.Properties.Durability)) < _items[itemIdentifier])
                {
                    MessageQueue.AddMessage(armorDescriptor.GetProperty<string>(GameConstants.Properties.BrokenMessage));
                    brokenList.Add(itemIdentifier);
                    wornList.Remove(itemIdentifier);
                }
            }
            if (brokenList.Count > 0)
            {
                foreach (string itemIdentifier in brokenList)
                {
                    _items.Remove(itemIdentifier);
                }
                AutoEquip();
            }
        }
        public void AutoEquip()
        {
            _weapon = String.Empty;
            foreach(string armorType in Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.PlayerConstants).GetProperty<HashSet<string>>(GameConstants.Properties.ArmorTypes))
            {
                _armors[armorType] = String.Empty;
            }
            if (GetProperty<PlayerConfiguration>(GameConstants.Properties.PlayerConfiguration).Current == HamQuestEngine.GameConstants.PlayerConfigurationValues.Attack)
            {
                AutoEquipWeapon();
                AutoEquipArmors();
            }
            else if (GetProperty<PlayerConfiguration>(GameConstants.Properties.PlayerConfiguration).Current == HamQuestEngine.GameConstants.PlayerConfigurationValues.Defend)
            {
                AutoEquipArmors();
                AutoEquipWeapon();
            }
        }
        public void Teleport()
        {
            Directions directions = new Directions();
            int count = 0;
            int mazeWidth = Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.MazeDimensions).GetProperty<int>(GameConstants.Properties.Columns);
            int mazeHeight = Maze.Game.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.MazeDimensions).GetProperty<int>(GameConstants.Properties.Rows);
            do
            {
                MazeColumn = Maze.Game.RandomNumberGenerator.Next(mazeWidth);
                MazeRow = Maze.Game.RandomNumberGenerator.Next(mazeHeight);
                count = 0;
                for (int direction = 0; direction < directions.Count; ++direction)
                {
                    if (Maze[MazeColumn][MazeRow].Portals[direction] != null && Maze[MazeColumn][MazeRow].Portals[direction].Open)
                    {
                        count++;
                    }
                }
            } while (count == 1);
            Map.PlayerCreature = null;
            MapCreature.Map = Maze[MazeColumn][MazeRow].CellInfo.Map;
            bool done = false;
            while (!done)
            {
                MapCreature.Column = Maze.Game.RandomNumberGenerator.Next(MapCreature.Map.Columns);
                MapCreature.Row = Maze.Game.RandomNumberGenerator.Next(MapCreature.Map.Rows);
                done = true;
                if (!Maze.Game.TableSet.TerrainTable.GetTerrainDescriptor(MapCreature.Map[MapCreature.Column][MapCreature.Row].TerrainIdentifier).GetProperty<bool>("passable"))
                {
                    done = false;
                    continue;
                }
                if (MapCreature.Map[MapCreature.Column][MapCreature.Row].ItemIdentifier != String.Empty)
                {
                    done = false;
                    continue;
                }
                if (MapCreature.Map[MapCreature.Column][MapCreature.Row].Creature != null)
                {
                    done = false;
                    continue;
                }
            }
            Map.PlayerCreature = MapCreature;
            Maze[MazeColumn][MazeRow].CellInfo.AddVisit();
        }
        public void AddItem(string itemIdentifier)
        {
            AddItem(itemIdentifier, true);
        }
        public bool HandleKey(Key key)
        {
            HashSet<string> keyHandlerNames = GetProperty<HashSet<string>>(GameConstants.Properties.KeyHandlers);
            foreach (string keyHandlerName in keyHandlerNames)
            {
                IPlayerKeyHandler keyHandler = GetProperty<IPlayerKeyHandler>(keyHandlerName);
                if (keyHandler.HandleKey(key, this))
                {
                    return true;
                }
            }
            return false;
        }
        public void AddItem(string itemIdentifier, bool reportToMessageQueue)
        {
            Descriptor itemDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
            string theItemType = itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType);
            if (theItemType == GameConstants.ItemTypes.Portal)
            {
                if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                MapCreature.Remove();
                Teleport();
                MapCreature.Place();
            }
            else
                if (theItemType == GameConstants.ItemTypes.Treasure)
                {
                    if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                    Money += (uint)(Maze.Game.RandomNumberGenerator.Next(itemDescriptor.GetProperty<int>(GameConstants.Properties.MaximumValue) - itemDescriptor.GetProperty<int>(GameConstants.Properties.MinimumValue) + 1) + itemDescriptor.GetProperty<int>(GameConstants.Properties.MinimumValue));
                }
                else
                    if (theItemType == GameConstants.ItemTypes.Quest)
                    {
                        if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                        Maze.SpawnMonsters(1.0f / (float)(Maze.Game.TableSet.ItemTable.QuestItemCount - QuestItems));
                        QuestItems++;
                        if (QuestItems == Maze.Game.TableSet.ItemTable.QuestItemCount)
                        {
                            MessageQueue.AddMessage(GetProperty<string>(GameConstants.Properties.QuestCompletedMessage));
                        }
                    }
                    else
                        if (theItemType == GameConstants.ItemTypes.Chest)
                        {
                            if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                        }
                        else
                            if (theItemType == GameConstants.ItemTypes.Armor)
                            {
                                if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                                AddItemDurability(itemIdentifier);
                                _items.Add(itemIdentifier);
                                AutoEquip();
                            }
                            else
                                if (theItemType == GameConstants.ItemTypes.Weapon)
                                {
                                    if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                                    _items.Add(itemIdentifier);
                                    AddItemDurability(itemIdentifier);
                                    AutoEquip();
                                }
                                else
                                    if (theItemType == GameConstants.ItemTypes.Trap)
                                    {
                                        CountedCollection<string> disarms = itemDescriptor.GetProperty<CountedCollection<string>>(GameConstants.Properties.ItemDisarms);
                                        bool canDisarm = true;
                                        foreach (string disarmIdentifier in disarms.Values)
                                        {
                                            if (disarms[disarmIdentifier] > _items[disarmIdentifier])
                                            {
                                                canDisarm = false;
                                                break;
                                            }
                                        }
                                        if (canDisarm)
                                        {
                                            foreach (string disarmIdentifier in disarms.Values)
                                            {
                                                _items.Remove(disarmIdentifier, disarms[disarmIdentifier]);
                                            }
                                            if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.DisarmMessage));
                                        }
                                        else
                                        {
                                            if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                                            TakeDamage(itemDescriptor.GetProperty<int>(GameConstants.Properties.AttackValue), 0);
                                            Map.PlayerCreature.BeenHit = true;
                                            if (MapCreature.Dead)
                                            {
                                                if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.KilledByMessage));
                                            }
                                        }
                                    }
                                    else
                                        if (theItemType == GameConstants.ItemTypes.Light)
                                        {
                                            if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                                            _items.Add(itemIdentifier);
                                            Descriptor lightItemDescriptor = Maze.Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                                            CountedCollection<string> durabilities = GetProperty<CountedCollection<string>>(GameConstants.Properties.ItemDurabilities);
                                            if (durabilities.Has(itemIdentifier))
                                            {
                                                durabilities[itemIdentifier] += (uint)lightItemDescriptor.GetProperty<int>(GameConstants.Properties.Duration);
                                            }
                                            else
                                            {
                                                durabilities.Add(itemIdentifier, (uint)lightItemDescriptor.GetProperty<int>(GameConstants.Properties.Duration));
                                            }
                                        }
                                        else
                                        {
                                            if (reportToMessageQueue) MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                                            _items.Add(itemIdentifier);
                                        }
        }
        
        private void HandleEndOfTurn()
        {
            decrementLightSource();
            rollSpeed();
        }
        public void Step()
        {
            GetProperty<PlayerStepTracker>(GameConstants.Properties.StepTracker).DoStep();
        }
        #endregion

        public static Descriptor LoadCustomDescriptor(PropertyValuePair[] thePropertyValues)
        {
            return new PlayerDescriptor(thePropertyValues);
        }
        public PlayerDescriptor(PropertyValuePair[] thePropertyValues)
            :base (thePropertyValues)
        {
            GetProperty<PlayerStatisticHolder>(GameConstants.Properties.Attack).GetValue = this.getAttack;
            GetProperty<PlayerStatisticHolder>(GameConstants.Properties.Health).GetValue = this.getHealth;
            GetProperty<PlayerStatisticHolder>(GameConstants.Properties.Speed).GetValue = this.getSpeed;
            GetProperty<PlayerStepTracker>(GameConstants.Properties.StepTracker).OnEndOfTurn = HandleEndOfTurn;
            GetProperty<PlayerConfiguration>(GameConstants.Properties.PlayerConfiguration).OnChange = AutoEquip;
            rollSpeed();
        }

        public void Initialize()
        {
            ExperienceLevel = GetProperty<int>(GameConstants.Properties.InitialExperienceLevel);
            ExperiencePoints = GetProperty<int>(GameConstants.Properties.InitialExperiencePoints);
            ExperienceGoal = GetProperty<int>(GameConstants.Properties.InitialExperienceGoal);
            MessageQueue.CallBacks -= messageQueueCallback;
            MessageQueue.CallBacks += messageQueueCallback;
            MessageQueue.AddMessage(GameConstants.Messages.Welcome1);
            MessageQueue.AddMessage(GameConstants.Messages.Welcome2);
            MessageQueue.AddMessage(GameConstants.Messages.Welcome3);
            MessageQueue.AddMessage(GameConstants.Messages.Welcome4);
            MessageQueue.AddMessage(GameConstants.Messages.Welcome5);
        }

        public void Lose()
        {
            _playerState = GameConstants.PlayerStates.Lose;
        }

        public void Win()
        {
            _playerState = GameConstants.PlayerStates.Win;
        }

        public bool Playing
        {
            get
            {
                return _playerState == GameConstants.PlayerStates.Play;
            }
        }

        public IEnumerable<string> EquippedArmors
        {
            get
            {
                return _armors.Values;
            }
        }

        public uint GetItemCount(string itemIdentifier)
        {
            return _items[itemIdentifier];
        }

        public bool HasItem(string itemIdentifier)
        {
            return GetItemCount(itemIdentifier) > 0;
        }

        public bool RemoveItems(string identifier, uint count)
        {
            if (_items[identifier] >= count)
            {
                _items[identifier] -= count;
                return true;
            }
            else
            {
                _items[identifier] = 0;
                return false;
            }
        }

        public bool RemoveItem(string identifier)
        {
            if (HasItem(identifier))
            {
                _items.Remove(identifier);
                return true;
            }
            else
            {
                return false;
            }
        }
    }
}