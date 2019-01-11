using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Media.Imaging;
using HamQuestEngine;
using PDGBoardGames;

namespace HamQuestSLClient
{
    public partial class MainPage : UserControl
    {
        private bool tutorialMode = true;
        private HashSet<string> tutorialTags = new HashSet<string>();

        const int MapTerrainLayer = 0;
        const int MapItemLayer = 3;
        const int MapCreatureLayer = 1;
        const int MapSplatLayer = 2;
        const int MapLayers=4;
        ImageCellMap imageCellMap;

        const int MiniMapHighlightLayer = 0;
        const int MiniMapBaseLayer = 1;
        const int MiniMapNorthLayer = 2;
        const int MiniMapEastLayer = 3;
        const int MiniMapSouthLayer = 4;
        const int MiniMapWestLayer = 5;
        const int MiniMapNorthDoorLayer = 6;
        const int MiniMapEastDoorLayer = 7;
        const int MiniMapSouthDoorLayer = 8;
        const int MiniMapWestDoorLayer = 9;
        const int MiniMapMarkerLayer = 10;
        const int MiniMapLayers = 11;
        ImageCellMap imageCellMiniMap;

        List<List<Image>> inventorySelectImages;
        List<List<Image>> inventoryStateImages;
        List<List<Image>> inventoryImages;
        List<List<TextBlock>> inventoryTextBlocks;
        List<List<TextBlock>> shadowTextBlocks;
        List<Image> statImages;
        List<TextBlock> statTextBlocks;
        List<TextBlock> messageTextBlocks;

        SoundEffectsManager sounds = new SoundEffectsManager();


        private void MessageStatisticsCallBack(string message, Color color)
        {
            Descriptor descriptor = game.TableSet.MessageTable.GetMessageDescriptor(message);
            if (descriptor != null)
            {
                if(descriptor.HasProperty(HamQuestEngine.GameConstants.Properties.SoundEffect))
                {
                    string soundEffect = descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.SoundEffect);
                    sounds.Play(soundEffect);
                }
                if (descriptor.HasProperty(HamQuestEngine.GameConstants.Properties.TutorialTag))
                {
                    message = descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.TutorialTag);
                }
                if (descriptor.HasProperty(HamQuestEngine.GameConstants.Properties.TutorialTitleText) && (descriptor.HasProperty(HamQuestEngine.GameConstants.Properties.AlwaysTutorial) || (tutorialMode && !tutorialTags.Contains(message))))
                {
                    tutorialTags.Add(message);
                    tutorialImage.Source = new BitmapImage(new Uri(descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.TutorialImagePath), UriKind.Relative));
                    stopTutorial.Visibility = descriptor.HasProperty(HamQuestEngine.GameConstants.Properties.AlwaysTutorial) ? Visibility.Collapsed : Visibility.Visible;
                    tutorialPanel.Visibility = Visibility.Visible;
                    tutorialItemName.Text = descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.TutorialTitleText);
                    tutorialDescription.Text = descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.TutorialDescriptionText);
                }
            }
        }

        public MainPage()
        {
            InitializeComponent();

            imageCellMap = new ImageCellMap(mapPanel.LayoutRoot, GameConstantsOld.Map.Cell.Columns, GameConstantsOld.Map.Cell.Rows, MapLayers, "images/map/misc/blank.png", true);
            imageCellMiniMap = new ImageCellMap(miniMapPanel, GameConstantsOld.Maze.Columns, GameConstantsOld.Maze.Rows, MiniMapLayers, "images/map/misc/blank.png", true);

            inventorySelectImages = new List<List<Image>>();
            inventoryStateImages = new List<List<Image>>();
            inventoryImages = new List<List<Image>>();
            inventoryTextBlocks = new List<List<TextBlock>>();
            shadowTextBlocks = new List<List<TextBlock>>();
            while (inventorySelectImages.Count < 5)
            {
                List<Image> cellColumn = new List<Image>();
                while (cellColumn.Count < 7)
                {
                    Image image = new Image();
                    image.Source = new BitmapImage(new Uri("images/map/misc/blank.png", UriKind.Relative));
                    inventoryPanel.Children.Add(image);
                    Grid.SetColumn(image, inventorySelectImages.Count);
                    Grid.SetRow(image, cellColumn.Count);
                    Grid.SetColumnSpan(image, 1);
                    Grid.SetRowSpan(image, 1);
                    cellColumn.Add(image);
                }
                inventorySelectImages.Add(cellColumn);
                cellColumn = new List<Image>();
                while (cellColumn.Count < 7)
                {
                    Image image = new Image();
                    image.Source = new BitmapImage(new Uri("images/map/misc/blank.png", UriKind.Relative));
                    inventoryPanel.Children.Add(image);
                    Grid.SetColumn(image, inventoryStateImages.Count);
                    Grid.SetRow(image, cellColumn.Count);
                    Grid.SetColumnSpan(image, 1);
                    Grid.SetRowSpan(image, 1);
                    cellColumn.Add(image);
                }
                inventoryStateImages.Add(cellColumn);
                cellColumn = new List<Image>();
                while (cellColumn.Count < 7)
                {
                    Image image = new Image();
                    image.Source = new BitmapImage(new Uri("images/map/misc/blank.png", UriKind.Relative));
                    inventoryPanel.Children.Add(image);
                    Grid.SetColumn(image, inventoryImages.Count);
                    Grid.SetRow(image, cellColumn.Count);
                    Grid.SetColumnSpan(image, 1);
                    Grid.SetRowSpan(image, 1);
                    cellColumn.Add(image);
                }
                inventoryImages.Add(cellColumn);
                List<TextBlock> textBlockColumn = new List<TextBlock>();
                while (textBlockColumn.Count < 7)
                {
                    TextBlock textBlock = new TextBlock();
                    textBlock.Foreground = new SolidColorBrush(Color.FromArgb(255,0,255,255));
                    textBlock.FontWeight = FontWeights.ExtraBlack;
                    textBlock.Margin = new Thickness(1);
                    inventoryPanel.Children.Add(textBlock);
                    Grid.SetColumn(textBlock, shadowTextBlocks.Count);
                    Grid.SetRow(textBlock, textBlockColumn.Count);
                    Grid.SetColumnSpan(textBlock, 1);
                    Grid.SetRowSpan(textBlock, 1);
                    textBlockColumn.Add(textBlock);
                }
                shadowTextBlocks.Add(textBlockColumn);
                textBlockColumn = new List<TextBlock>();
                while (textBlockColumn.Count < 7)
                {
                    TextBlock textBlock = new TextBlock();
                    textBlock.Foreground = new SolidColorBrush(Color.FromArgb(255, 0, 0, 0));
                    textBlock.FontWeight = FontWeights.ExtraBlack;
                    textBlock.Margin = new Thickness(0);
                    inventoryPanel.Children.Add(textBlock);
                    Grid.SetColumn(textBlock, inventoryTextBlocks.Count);
                    Grid.SetRow(textBlock, textBlockColumn.Count);
                    Grid.SetColumnSpan(textBlock, 1);
                    Grid.SetRowSpan(textBlock, 1);
                    textBlockColumn.Add(textBlock);
                }
                inventoryTextBlocks.Add(textBlockColumn);
            }
            statImages = new List<Image>();
            statTextBlocks = new List<TextBlock>();
            while (statImages.Count < 6)
            {
                Image image = new Image();
                statisticPanel.Children.Add(image);
                Grid.SetColumn(image, (statImages.Count>=3)?(5):(0));
                Grid.SetRow(image, statImages.Count % 3);
                Grid.SetColumnSpan(image, 1);
                Grid.SetRowSpan(image, 1);
                statImages.Add(image);
                TextBlock textBlock = new TextBlock();
                textBlock.FontWeight = FontWeights.ExtraBlack;
                statisticPanel.Children.Add(textBlock);
                Grid.SetColumn(textBlock, (statTextBlocks.Count >= 3) ? (6) : (1));
                Grid.SetRow(textBlock, statTextBlocks.Count % 3);
                Grid.SetColumnSpan(textBlock, 4);
                Grid.SetRowSpan(textBlock, 1);
                statTextBlocks.Add(textBlock);
            }
            statImages[0].Source = new BitmapImage(new Uri("images/statistics/attack.png", UriKind.Relative));
            statImages[1].Source = new BitmapImage(new Uri("images/statistics/defend.png", UriKind.Relative));
            statImages[2].Source = new BitmapImage(new Uri("images/statistics/health.png", UriKind.Relative));
            statImages[3].Source = new BitmapImage(new Uri("images/statistics/speed.png", UriKind.Relative));
            statImages[4].Source = new BitmapImage(new Uri("images/statistics/experience.png", UriKind.Relative));
            statImages[5].Source = new BitmapImage(new Uri("images/statistics/level.png", UriKind.Relative));
            RectangleGeometry geom = new RectangleGeometry();
            geom.Rect = new Rect(0, 0, 480, 480);
            lightCanvas.Clip = geom;
            messageTextBlocks = new List<TextBlock>();
            while (messageTextBlocks.Count < 5)
            {
                TextBlock textBlock = new TextBlock();
                messagePanel.Children.Add(textBlock);
                Grid.SetColumn(textBlock, 0);
                Grid.SetRow(textBlock, messageTextBlocks.Count);
                Grid.SetColumnSpan(textBlock, 1);
                Grid.SetRowSpan(textBlock, 1);
                messageTextBlocks.Add(textBlock);
            }
        }
        private void drawMap()
        {
            Map map = game.Maze[game.Maze.PlayerDescriptor.MazeColumn][game.Maze.PlayerDescriptor.MazeRow].CellInfo.Map;
            Descriptor descriptor;
            for (int column = 0; column < imageCellMap.Columns; ++column)
            {
                for (int row = 0; row < imageCellMap.Rows; ++row)
                {
                    descriptor = game.TableSet.TerrainTable.GetTerrainDescriptor(map[column][row].TerrainIdentifier);
                    imageCellMap[column][row][MapTerrainLayer].ImageSource = descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.ImagePath);
                    descriptor = game.TableSet.ItemTable.GetItemDescriptor(map[column][row].ItemIdentifier);
                    if (descriptor == null)
                    {
                        imageCellMap[column][row][MapItemLayer].Visible = false;
                    }
                    else
                    {
                        imageCellMap[column][row][MapItemLayer].Visible = true;
                        imageCellMap[column][row][MapItemLayer].ImageSource = descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.ImagePath);
                    }
                    Creature creature = map[column][row].Creature;
                    if (creature == null)
                    {
                        imageCellMap[column][row][MapCreatureLayer].Visible = false;
                        imageCellMap[column][row][MapSplatLayer].Visible = false;
                    }
                    else
                    {
                        imageCellMap[column][row][MapCreatureLayer].Visible = true;
                        descriptor = game.TableSet.CreatureTable.GetCreatureDescriptor(creature.CreatureIdentifier);
                        imageCellMap[column][row][MapCreatureLayer].ImageSource = descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.ImagePath);
                        if (creature.BeenHit)
                        {
                            imageCellMap[column][row][MapSplatLayer].ImageSource = "images/map/creatures/misc/splat.png";
                            imageCellMap[column][row][MapSplatLayer].Visible = true;
                        }
                        else
                        {
                            imageCellMap[column][row][MapSplatLayer].Visible = false;
                        }
                        creature.BeenHit = false;
                    }
                }
            }
            Creature playerCreature = Map.PlayerCreature;
            Canvas.SetLeft(lightImage, -480+playerCreature.Column*32+16);
            Canvas.SetTop(lightImage, -480+playerCreature.Row*32+16);
            descriptor = game.TableSet.ItemTable.GetItemDescriptor(game.Maze.PlayerDescriptor.LightSource);
            lightImage.Source = new BitmapImage(new Uri(descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.LightRadiusImagePath), UriKind.Relative));
        }
        private void drawMiniMap()
        {
            string[] doorTypes = new string[] { "red","yellow","green","cyan","blue","magenta"};
            for (int column = 0; column < game.Maze.Columns; ++column)
            {
                for (int row = 0; row < game.Maze.Rows; ++row)
                {
                    if (game.Maze[column][row].CellInfo.VisitCount > 0)
                    {
                        if (column == game.Maze.PlayerDescriptor.MazeColumn && row == game.Maze.PlayerDescriptor.MazeRow)
                        {
                            imageCellMiniMap[column][row][MiniMapHighlightLayer].Visible = true;
                            imageCellMiniMap[column][row][MiniMapHighlightLayer].ImageSource = "images/minimap/misc/highlight.png";
                        }
                        else
                        {
                            imageCellMiniMap[column][row][MiniMapHighlightLayer].Visible = false;
                        }

                        if (game.Maze[column][row].CellInfo.Map.HasCreature && game.Maze[column][row].CellInfo.Map.HasItem)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/redgreen.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasCreature && game.Maze[column][row].CellInfo.Map.HasExit)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/redyellow.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasCreature && game.Maze[column][row].CellInfo.Map.HasPortal)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/redblue.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasCreature)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/red.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasItem && game.Maze[column][row].CellInfo.Map.HasExit)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/yellowgreen.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasPortal && game.Maze[column][row].CellInfo.Map.HasExit)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/yellowblue.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasItem && game.Maze[column][row].CellInfo.Map.HasPortal)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/greenblue.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasItem)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/green.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasExit)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/yellow.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else if (game.Maze[column][row].CellInfo.Map.HasPortal)
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].ImageSource = "images/minimap/markers/blue.png";
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = true;
                        }
                        else
                        {
                            imageCellMiniMap[column][row][MiniMapMarkerLayer].Visible = false;
                        }

                        imageCellMiniMap[column][row][MiniMapBaseLayer].Visible = true;
                        string roomType = (game.Maze[column][row].CellInfo.CellType == HamQuestEngine.GameConstants.CellTypes.Room) ? ((game.Maze[column][row].CellInfo.Map.HasQuest && game.Maze.PlayerDescriptor.HasItem("Compass")) ? ("quest") : ("chamber")) : ("passageway");
                        imageCellMiniMap[column][row][MiniMapBaseLayer].ImageSource=string.Format("images/minimap/{0}/base.png", roomType);

                        if (game.Maze[column][row].Portals[0] != null && game.Maze[column][row].Portals[0].Open)
                        {
                            imageCellMiniMap[column][row][MiniMapNorthLayer].ImageSource = string.Format("images/minimap/{0}/north.png", roomType);
                            imageCellMiniMap[column][row][MiniMapNorthLayer].Visible = true;
                            if (game.Maze[column][row].Portals[0].Locked)
                            {
                                imageCellMiniMap[column][row][MiniMapNorthDoorLayer].ImageSource = string.Format("images/minimap/doors/{0}/north.png", doorTypes[game.Maze[column][row].Portals[0].LockType]);
                                imageCellMiniMap[column][row][MiniMapNorthDoorLayer].Visible=true;
                            }
                            else
                            {
                                imageCellMiniMap[column][row][MiniMapNorthDoorLayer].Visible = false;
                            }
                        }
                        else
                        {
                            imageCellMiniMap[column][row][MiniMapNorthLayer].Visible = false;
                            imageCellMiniMap[column][row][MiniMapNorthDoorLayer].Visible = false;
                        }

                        if (game.Maze[column][row].Portals[1] != null && game.Maze[column][row].Portals[1].Open)
                        {
                            imageCellMiniMap[column][row][MiniMapEastLayer].ImageSource = string.Format("images/minimap/{0}/east.png", roomType);
                            imageCellMiniMap[column][row][MiniMapEastLayer].Visible = true;
                            if (game.Maze[column][row].Portals[1].Locked)
                            {
                                imageCellMiniMap[column][row][MiniMapEastDoorLayer].ImageSource = string.Format("images/minimap/doors/{0}/east.png", doorTypes[game.Maze[column][row].Portals[1].LockType]);
                                imageCellMiniMap[column][row][MiniMapEastDoorLayer].Visible = true;
                            }
                            else
                            {
                                imageCellMiniMap[column][row][MiniMapEastDoorLayer].Visible = false;
                            }
                        }
                        else
                        {
                            imageCellMiniMap[column][row][MiniMapEastLayer].Visible = false;
                            imageCellMiniMap[column][row][MiniMapEastDoorLayer].Visible = false;
                        }

                        if (game.Maze[column][row].Portals[2] != null && game.Maze[column][row].Portals[2].Open)
                        {
                            imageCellMiniMap[column][row][MiniMapSouthLayer].ImageSource = string.Format("images/minimap/{0}/south.png", roomType);
                            imageCellMiniMap[column][row][MiniMapSouthLayer].Visible = true;
                            if (game.Maze[column][row].Portals[2].Locked)
                            {
                                imageCellMiniMap[column][row][MiniMapSouthDoorLayer].ImageSource = string.Format("images/minimap/doors/{0}/south.png", doorTypes[game.Maze[column][row].Portals[2].LockType]);
                                imageCellMiniMap[column][row][MiniMapSouthDoorLayer].Visible = true;
                            }
                            else
                            {
                                imageCellMiniMap[column][row][MiniMapSouthDoorLayer].Visible = false;
                            }
                        }
                        else
                        {
                            imageCellMiniMap[column][row][MiniMapSouthLayer].Visible = false;
                            imageCellMiniMap[column][row][MiniMapSouthDoorLayer].Visible = false;
                        }

                        if (game.Maze[column][row].Portals[3] != null && game.Maze[column][row].Portals[3].Open)
                        {
                            imageCellMiniMap[column][row][MiniMapWestLayer].ImageSource = string.Format("images/minimap/{0}/west.png", roomType);
                            imageCellMiniMap[column][row][MiniMapWestLayer].Visible = true;
                            if (game.Maze[column][row].Portals[3].Locked)
                            {
                                imageCellMiniMap[column][row][MiniMapWestDoorLayer].ImageSource = string.Format("images/minimap/doors/{0}/west.png", doorTypes[game.Maze[column][row].Portals[3].LockType]);
                                imageCellMiniMap[column][row][MiniMapWestDoorLayer].Visible = true;
                            }
                            else
                            {
                                imageCellMiniMap[column][row][MiniMapWestDoorLayer].Visible = false;
                            }
                        }
                        else
                        {
                            imageCellMiniMap[column][row][MiniMapWestLayer].Visible = false;
                            imageCellMiniMap[column][row][MiniMapWestDoorLayer].Visible = false;
                        }
                    }
                    else
                    {
                        for (int layer = 0; layer < imageCellMiniMap.Layers; ++layer)
                        {
                            imageCellMiniMap[column][row][layer].Visible = false;
                        }
                    }
                }
            }
        }
        private string formatInventoryCount(uint theCount)
        {
            if (theCount > 10000000)
            {
                return string.Format("{0}M",(theCount/1000000));
            }
            else if (theCount > 1000000)
            {
                return string.Format("{0}.{1}M", (theCount / 1000000), (theCount%1000000)/100000);
            }
            else if (theCount > 10000)
            {
                return string.Format("{0}K", (theCount / 1000));
            }
            else if (theCount > 1000)
            {
                return string.Format("{0}.{1}K", (theCount / 1000), (theCount % 1000) / 100);
            }
            else
            {
                return theCount.ToString();
            }
        }
        private void drawInventory()
        {
            int row = 0;
            int column = 0;
            for (column = 0; column < 5; ++column)
            {
                for (row = 0; row < 7; ++row)
                {
                    inventorySelectImages[column][row].Visibility = Visibility.Collapsed;
                    inventoryStateImages[column][row].Visibility = Visibility.Collapsed;
                    inventoryImages[column][row].Visibility = Visibility.Collapsed;
                    inventoryTextBlocks[column][row].Visibility = Visibility.Collapsed;
                    shadowTextBlocks[column][row].Visibility = Visibility.Collapsed;
                }
            }
            foreach (string itemIdentifier in game.Maze.PlayerDescriptor.ItemIdentifiers)
            {
                column = game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier).GetProperty<int>("inventory-column");
                row = game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier).GetProperty<int>("inventory-row");
                if (column < 0) continue;
                inventorySelectImages[column][row].Visibility = Visibility.Visible;
                inventoryStateImages[column][row].Visibility = Visibility.Visible;
                inventoryImages[column][row].Visibility = Visibility.Visible;
                inventoryTextBlocks[column][row].Visibility = Visibility.Visible;
                shadowTextBlocks[column][row].Visibility = Visibility.Visible;
                Descriptor itemDescriptor = game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                if (game.Maze.PlayerDescriptor.IsEquipped(itemIdentifier))
                {
                    inventoryStateImages[column][row].Visibility = Visibility.Visible;
                    inventorySelectImages[column][row].Source=new BitmapImage(new Uri("images/map/ui/selection.png", UriKind.Relative));
                }
                else
                {
                    inventoryStateImages[column][row].Visibility = Visibility.Collapsed;
                    inventorySelectImages[column][row].Source = new BitmapImage(new Uri("images/map/misc/blank.png", UriKind.Relative));
                }
                inventoryImages[column][row].Source = new BitmapImage(new Uri(itemDescriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.ImagePath), UriKind.Relative));
                inventoryTextBlocks[column][row].Text = formatInventoryCount(game.Maze.PlayerDescriptor.GetItemCount(itemIdentifier));
                shadowTextBlocks[column][row].Text = formatInventoryCount(game.Maze.PlayerDescriptor.GetItemCount(itemIdentifier));
                if (game.Maze.PlayerDescriptor.IsEquipped(itemIdentifier))
                {
                    float fraction = 0.0f;
                    if (itemDescriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.ItemType) == HamQuestEngine.GameConstants.ItemTypes.Weapon)
                    {
                        Descriptor weaponDescriptor = itemDescriptor;
                        fraction = (float)(game.Maze.PlayerDescriptor.GetProperty<CountedCollection<string>>(HamQuestEngine.GameConstants.Properties.ItemDurabilities)[itemIdentifier] - ((game.Maze.PlayerDescriptor.GetItemCount(itemIdentifier) - 1) * weaponDescriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Durability))) / (float)weaponDescriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Durability);
                    }
                    else if (itemDescriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.ItemType) == HamQuestEngine.GameConstants.ItemTypes.Armor)
                    {
                        fraction = (float)(game.Maze.PlayerDescriptor.GetProperty<CountedCollection<string>>(HamQuestEngine.GameConstants.Properties.ItemDurabilities)[itemIdentifier] - ((game.Maze.PlayerDescriptor.GetItemCount(itemIdentifier) - 1) * itemDescriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Durability))) / (float)itemDescriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Durability);
                    }
                    else if (itemDescriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.ItemType) == HamQuestEngine.GameConstants.ItemTypes.Light)
                    {
                        Descriptor lightDescriptor = itemDescriptor;
                        fraction = (float)(game.Maze.PlayerDescriptor.GetProperty<CountedCollection<string>>(HamQuestEngine.GameConstants.Properties.ItemDurabilities)[itemIdentifier] - ((game.Maze.PlayerDescriptor.GetItemCount(itemIdentifier) - 1) * lightDescriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Duration))) / (float)lightDescriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Duration);
                    }
                    if (fraction <= 0.25f)
                    {
                        inventoryStateImages[column][row].Source = new BitmapImage(new Uri("images/map/ui/reddurability.png", UriKind.Relative));
                    }
                    else if (fraction <= 0.5f)
                    {
                        inventoryStateImages[column][row].Source = new BitmapImage(new Uri("images/map/ui/yellowdurability.png", UriKind.Relative));
                    }
                    else
                    {
                        inventoryStateImages[column][row].Source = new BitmapImage(new Uri("images/map/misc/blank.png", UriKind.Relative));
                    }
                }
            }
        }
        private void drawMessages()
        {
            if (game.Maze.PlayerDescriptor.MessageQueue.Messages != null)
            {
                for (int index = 0; index < messageTextBlocks.Count; ++index)
                {
                    if (index < game.Maze.PlayerDescriptor.MessageQueue.Messages.Length)
                    {
                        messageTextBlocks[index].Text = game.Maze.PlayerDescriptor.MessageQueue.Messages[index];
                        messageTextBlocks[index].Foreground = new SolidColorBrush(game.Maze.PlayerDescriptor.MessageQueue.Colors[index]);
                    }
                    else
                    {
                        messageTextBlocks[index].Text = "";
                    }
                }
            }
            else
            {
                for (int index = 0; index < messageTextBlocks.Count; ++index)
                {
                    messageTextBlocks[index].Text = "";
                }
            }
        }
        private void drawStatistics()
        {

            statTextBlocks[0].Text = string.Format("{0}", game.Maze.PlayerDescriptor.GetProperty<IStatisticHolder>(HamQuestEngine.GameConstants.Properties.Attack).Value);
            statTextBlocks[1].Text = string.Format("{0}", game.Maze.PlayerDescriptor.GetProperty<IRoller>(HamQuestEngine.GameConstants.Properties.DefendRoller).GetMaximumRoll(game.Maze.PlayerDescriptor,game));
            statTextBlocks[2].Text = string.Format("{0}/{1}", game.Maze.PlayerDescriptor.GetProperty<IStatisticHolder>("health").Value - game.Maze.PlayerDescriptor.MapCreature.Wounds, game.Maze.PlayerDescriptor.GetProperty<IStatisticHolder>("health").Value);
            statTextBlocks[3].Text = string.Format("{0}", game.Maze.PlayerDescriptor.GetProperty<IStatisticHolder>("speed").Value);
            statTextBlocks[4].Text = string.Format("{0}/{1}", game.Maze.PlayerDescriptor.ExperiencePoints, game.Maze.PlayerDescriptor.ExperienceGoal);
            statTextBlocks[5].Text = string.Format("{0}", game.Maze.PlayerDescriptor.ExperienceLevel);
            if (game.Maze.PlayerDescriptor.GetProperty<PlayerConfiguration>(HamQuestEngine.GameConstants.Properties.PlayerConfiguration).Current == HamQuestEngine.GameConstants.PlayerConfigurationValues.Defend)
            {
                selectAttackMode.Visibility = Visibility.Collapsed;
                selectDefendMode.Visibility = Visibility.Visible;
            }
            else
            {
                selectAttackMode.Visibility = Visibility.Visible;
                selectDefendMode.Visibility = Visibility.Collapsed;
            }
        }
        Game game = new Game();
        private void newGame()
        {
            game.Initialize();
            drawMiniMap();
            drawMap();
            drawInventory();
            drawStatistics();
            drawMessages();
        }
        private void LayoutRoot_Loaded(object sender, RoutedEventArgs e)
        {
            newGame();
            game.Maze.PlayerDescriptor.MessageQueue.CallBacks += new MessageQueueCallBack(MessageStatisticsCallBack);
            this.Focus();
        }
        private void newGameCommand()
        {
            PlayerDescriptor descriptor = game.Maze.PlayerDescriptor;
            if (descriptor.Playing)
            {
                if (MessageBox.Show("Are you sure you want to start a new game?", "Are you sure?",MessageBoxButton.OKCancel) != MessageBoxResult.OK)
                {
                    return;
                }
            }
            newGame();
            game.Maze.PlayerDescriptor.MessageQueue.CallBacks += new MessageQueueCallBack(MessageStatisticsCallBack);
        }
        private void toggleFightModeCommand()
        {
            PlayerDescriptor descriptor = game.Maze.PlayerDescriptor;
            if (descriptor.Playing)
            {
                setFightModeCommand((descriptor.GetProperty<PlayerConfiguration>(HamQuestEngine.GameConstants.Properties.PlayerConfiguration).Current == HamQuestEngine.GameConstants.PlayerConfigurationValues.Attack) ? (HamQuestEngine.GameConstants.PlayerConfigurationValues.Defend) : (HamQuestEngine.GameConstants.PlayerConfigurationValues.Attack));
            }
        }
        private void setFightModeCommand(string configuration)
        {
            PlayerDescriptor descriptor = game.Maze.PlayerDescriptor;
            if (descriptor.Playing)
            {
                descriptor.GetProperty<PlayerConfiguration>(HamQuestEngine.GameConstants.Properties.PlayerConfiguration).Current = configuration;
                drawStatistics();
                drawInventory();
            }
        }
        private void HandleKey(Key key)
        {
            if (key == Key.None) return;
            if (tutorialPanel.Visibility == Visibility.Visible)
            {
                if (key == Key.Enter || key == Key.Escape)
                {
                    tutorialPanel.Visibility = Visibility.Collapsed;
                }
                return;
            }
            if (shopDialog.Visibility == Visibility.Visible)
            {
                if (key == Key.Enter || key == Key.Escape)
                {
                    shopDialog.Visibility = Visibility.Collapsed;
                }
                return;
            }
            if (mainMenu.Visibility == Visibility.Visible)
            {
                if (key == Key.Enter || key == Key.Escape)
                {
                    mainMenu.Visibility = Visibility.Collapsed;
                    controlsPanel.Visibility = Visibility.Collapsed;
                    settingsPanel.Visibility = Visibility.Collapsed;
                    aboutBox.Visibility = Visibility.Collapsed;
                }
                return;
            }
            switch (key)
            {
                //case Keys.Escape:
                //    ShowMenu();
                //    return;
                //case Keys.F1:
                //    ShowHelpBox();
                //    return;
                case Key.F2:
                    newGameCommand();
                    return;
                case Key.Tab:
                    toggleFightModeCommand();
                    return;
                case Key.Up:
                    moveCommand(Directions.North);
                    return;
                case Key.Left:
                    moveCommand(Directions.West);
                    return;
                case Key.Down:
                    moveCommand(Directions.South);
                    return;
                case Key.Right:
                    moveCommand(Directions.East);
                    return;
                default:
                    if (game.Maze.PlayerDescriptor.HandleKey(key))
                    {
                        updateGameCommand();
                    }
                    return;
            }
        }
        private void moveCommand(int direction)
        {
            PlayerDescriptor descriptor = game.Maze.PlayerDescriptor;
            if (descriptor.Playing)
            {
                descriptor.MapCreature.Move(direction);
                updateGameCommand();
            }
        }
        private void drawShop()
        {
            ShopState shopState = game.Maze.PlayerDescriptor.ShopState;
            shopTitle.Text = shopState.ShopTitle;
            shopItems.Items.Clear();
            Descriptor descriptor;
            foreach (string itemIdentifier in shopState.ItemList)
            {
                descriptor = game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                shopItems.Items.Add(String.Format("{0} (In Stock:{1}, Price:{2})", descriptor.GetProperty<string>(HamQuestEngine.GameConstants.Properties.Name), shopState.ShopItems[itemIdentifier], descriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Price)));
            }
            if (shopState.ItemIndex >= 0 && shopState.ItemIndex < shopState.ItemList.Count)
            {
                shopItems.SelectedIndex = shopState.ItemIndex;
            }
            updateShopButtons();
            shopDialog.Visibility = Visibility.Visible;
        }
        private void updateShopButtons()
        {
            ShopState shopState = game.Maze.PlayerDescriptor.ShopState;
            availableGold.Text = string.Format("Gold Available: {0}", game.Maze.PlayerDescriptor.Money);
            Descriptor descriptor = game.TableSet.ItemTable.GetItemDescriptor(shopState.ItemList[shopState.ItemIndex]);
            buyOne.Content = string.Format("Buy One(Costs {0} Gold)", descriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Price));
            buyOne.IsEnabled = shopState.ShopItems[shopState.ItemList[shopState.ItemIndex]] > 0 && (game.Maze.PlayerDescriptor.Money >= descriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Price));
            buyAll.Content = string.Format("Buy All(Costs {0} Gold)", descriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Price) * shopState.ShopItems[shopState.ItemList[shopState.ItemIndex]]);
            buyAll.IsEnabled = shopState.ShopItems[shopState.ItemList[shopState.ItemIndex]] > 0 && (game.Maze.PlayerDescriptor.Money >= descriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Price) * shopState.ShopItems[shopState.ItemList[shopState.ItemIndex]]);
        }
        private void updateGameCommand()
        {
            Map map = game.Maze[game.Maze.PlayerDescriptor.MazeColumn][game.Maze.PlayerDescriptor.MazeRow].CellInfo.Map;
            PlayerDescriptor descriptor = game.Maze.PlayerDescriptor;
            Creature creature = Map.PlayerCreature;
            game.Maze.PlayerDescriptor.Step();
            map = game.Maze[game.Maze.PlayerDescriptor.MazeColumn][game.Maze.PlayerDescriptor.MazeRow].CellInfo.Map;
            map.MoveCreatures(1.0f / (float)game.Maze.PlayerDescriptor.GetProperty<IStatisticHolder>("speed").Value);
            drawMap();
            drawMiniMap();
            drawInventory();
            drawStatistics();
            drawMessages();
            map.RemoveDeadCreatures();
            if (descriptor.ShopState != null)
            {
                drawShop();
            }
        }

        public void LayoutRoot_KeyDown(object sender, KeyEventArgs e)
        {
            HandleKey(e.Key);
        }

        private void shopItems_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (game.Maze.PlayerDescriptor.ShopState == null)
            {
                return;
            }
            if (game.Maze.PlayerDescriptor.ShopState.ItemIndex != shopItems.SelectedIndex)
            {
                game.Maze.PlayerDescriptor.ShopState.ItemIndex = shopItems.SelectedIndex;
                updateShopButtons();
            }
        }

        private void buyOne_Click(object sender, RoutedEventArgs e)
        {
            ShopState shopState = game.Maze.PlayerDescriptor.ShopState;
            string itemIdentifier = shopState.ItemList[shopState.ItemIndex];
            Descriptor descriptor = game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
            game.Maze.PlayerDescriptor.Money -= (uint)descriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Price);
            shopState.ShopItems.Remove(itemIdentifier);
            game.Maze.PlayerDescriptor.AddItem(itemIdentifier);
            drawShop();
            drawInventory();
            drawStatistics();
            drawMessages();
        }

        private void buyAll_Click(object sender, RoutedEventArgs e)
        {
            ShopState shopState = game.Maze.PlayerDescriptor.ShopState;
            string itemIdentifier = shopState.ItemList[shopState.ItemIndex];
            Descriptor descriptor = game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
            while (shopState.ShopItems[itemIdentifier]>0)
            {
                game.Maze.PlayerDescriptor.Money -= (uint)descriptor.GetProperty<int>(HamQuestEngine.GameConstants.Properties.Price);
                shopState.ShopItems.Remove(itemIdentifier);
                game.Maze.PlayerDescriptor.AddItem(itemIdentifier);
            }
            drawShop();
            drawInventory();
            drawStatistics();
            drawMessages();
        }

        private void leaveShop_Click(object sender, RoutedEventArgs e)
        {
            game.Maze.PlayerDescriptor.ShopState = null;
            shopDialog.Visibility = Visibility.Collapsed;
            updateGameCommand();
        }

        private void playGame_Click(object sender, RoutedEventArgs e)
        {
            mainMenu.Visibility = Visibility.Collapsed;
        }

        private void controls_Click(object sender, RoutedEventArgs e)
        {
            controlsPanel.Visibility = Visibility.Visible;
        }

        private void settings_Click(object sender, RoutedEventArgs e)
        {
            settingsPanel.Visibility = Visibility.Visible;
        }

        private void about_Click(object sender, RoutedEventArgs e)
        {
            aboutBox.Visibility = Visibility.Visible;
        }

        private void closeAbout_Click(object sender, RoutedEventArgs e)
        {
            aboutBox.Visibility = Visibility.Collapsed;
        }

        private void closeSettings_Click(object sender, RoutedEventArgs e)
        {
            settingsPanel.Visibility = Visibility.Collapsed;
        }

        private void closeControls_Click(object sender, RoutedEventArgs e)
        {
            controlsPanel.Visibility = Visibility.Collapsed;
        }

        private void closeTutorial_Click(object sender, RoutedEventArgs e)
        {
            tutorialPanel.Visibility = System.Windows.Visibility.Collapsed;
        }

        private void stopTutorial_Click(object sender, RoutedEventArgs e)
        {
            tutorialMode = false;
            tutorialPanel.Visibility = System.Windows.Visibility.Collapsed;
        }

        private void keyPickupSound_DownloadProgressChanged(object sender, RoutedEventArgs e)
        {
            sounds[Constants.SoundEffects.KeyPickUp] = keyPickupSound;
        }

        private void doorOpenSound_DownloadProgressChanged(object sender, RoutedEventArgs e)
        {
            sounds[Constants.SoundEffects.DoorUnlockSound] = doorOpenSound;
        }

    }
}
