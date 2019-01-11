using System;
using System.Collections.Generic;
using System.Text;
using System.Xml.Linq;
using System.Reflection;

namespace HamQuestEngine
{
    public class PropertyValuePair
    {
        private string property;
        private object value;
        public string Property
        {
            get
            {
                return property;
            }
        }
        public object Value
        {
            get
            {
                return value;
            }
        }
        public PropertyValuePair(string theProperty, object theValue)
        {
            property = theProperty;
            value = theValue;
        }
        private static List<Type> registeredTypes = new List<Type>();
        public static void RegisterType(Type theType)
        {
            UnregisterType(theType);
            registeredTypes.Add(theType);
        }
        public static void UnregisterType(Type theType)
        {
            registeredTypes.Remove(theType);
        }
        private const char Delimiter = ',';
        public static PropertyValuePair[] LoadPropertyValuesFromXmlNode(XElement node,out string identifier)
        {
            identifier = String.Empty;
            List<PropertyValuePair> properties = new List<PropertyValuePair>();
            if (node.Attribute(GameConstants.Attributes.Template) != null)
            {
                string[] filenames = node.Attribute(GameConstants.Attributes.Template).Value.Split(Delimiter);
                foreach(string filename in filenames)
                {
                    XDocument doc = XDocument.Load(filename);
                    string oldidentifier = identifier;
                    PropertyValuePair[] data = LoadPropertyValuesFromXmlNode(doc.Element(node.Name), out identifier);
                    identifier = oldidentifier + identifier;
                    properties.AddRange(data);
                }
            }
            foreach (XElement subElement in node.Elements())
            {
                if (subElement.Name.LocalName == GameConstants.Properties.Identifier)
                {
                    identifier += subElement.Value;
                }
                else if (subElement.Attribute(GameConstants.Attributes.Type) != null)
                {
                    string name = subElement.Name.LocalName;
                    string typeName = subElement.Attribute(GameConstants.Attributes.Type).Value;
                    Assembly assembly = Assembly.GetExecutingAssembly();
                    Type[] types = assembly.GetExportedTypes();
                    foreach (Type type in types)
                    {
                        if (type.Name == typeName)
                        {
                            MethodInfo methodInfo = type.GetMethod(GameConstants.Methods.LoadFromNode);
                            properties.Add(new PropertyValuePair(name, methodInfo.Invoke(null, new object[] { subElement })));
                            break;
                        }
                    }
                    foreach (Type type in registeredTypes)
                    {
                        if (type.Name == typeName)
                        {
                            MethodInfo methodInfo = type.GetMethod(GameConstants.Methods.LoadFromNode);
                            properties.Add(new PropertyValuePair(name, methodInfo.Invoke(null, new object[] { subElement })));
                            break;
                        }
                    }
                }
                else
                {
                    string name = subElement.Name.LocalName;
                    string value = subElement.Value;
                    int intValue;
                    bool boolValue;
                    float floatValue;
                    if (int.TryParse(value, out intValue))
                    {
                        properties.Add(new PropertyValuePair(name, intValue));
                    }
                    else if (float.TryParse(value, out floatValue))
                    {
                        properties.Add(new PropertyValuePair(name, floatValue));
                    }
                    else if (bool.TryParse(value, out boolValue))
                    {
                        properties.Add(new PropertyValuePair(name, boolValue));
                    }
                    else
                    {
                        properties.Add(new PropertyValuePair(name, value));
                    }
                }
            }
            return properties.ToArray();
        }
        public static PropertyValuePair[] CombineArrays(PropertyValuePair[] first, PropertyValuePair[] second)
        {
            List<PropertyValuePair> temp = new List<PropertyValuePair>(first);
            temp.AddRange(second);
            return temp.ToArray();
        }
    }
    public class Descriptor
    {
        private Dictionary<string, object> properties = new Dictionary<string, object>();
        protected virtual bool HasPropertyIntercept(string property)
        {
            return false;
        }
        public bool HasProperty(string property)
        {
            if (HasPropertyIntercept(property))
            {
                return true;
            }
            else
            {
                return properties.ContainsKey(property);
            }
            
        }
        private void SetProperty(string property, object value)
        {
            if (value == null)
            {
                if (HasProperty(property))
                {
                    properties.Remove(property);
                }
            }
            else
            {
                if (HasProperty(property))
                {
                    properties[property] = value;
                }
                else
                {
                    properties.Add(property, value);
                }
            }
        }
        protected virtual E GetPropertyIntercept<E>(string property)
        {
            return default(E);
        }
        public E GetProperty<E>(string property)
        {
            try
            {
                if (HasPropertyIntercept(property))
                {
                    return GetPropertyIntercept<E>(property);
                }
                else
                {
                    E e = (E)properties[property];
                    return e;
                }
            }
            catch
            {
                return default(E);
            }
        }

        private Descriptor()
        {
        }
        protected void AddPropertyValues(PropertyValuePair[] thePropertyValues)
        {
            foreach (PropertyValuePair propertyValue in thePropertyValues)
            {
                SetProperty(propertyValue.Property, propertyValue.Value);
            }
        }
        public Descriptor(PropertyValuePair[] thePropertyValues)
        {
            AddPropertyValues(thePropertyValues);
        }
    }
}
