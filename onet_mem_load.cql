// Upload ONET DATA

LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_scalesreference.csv' WITH HEADER AS row 
MERGE (scale:ONET_Scale {key: row.scale_id}) 
ON CREATE SET scale.title = toLower(row.scale_name), scale.min = toInteger(row.minimum), scale.max = toInteger(row.maximum);

LOAD CSV FROM '/usr/lib/memgraph/import/onet/trusted_alternatetitles.csv' WITH HEADER AS row 
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MERGE (b:ONET_Occupation {title: toLower(row.alternate_title)})
WITH a, b, row
MERGE (a)<-[:ALT_TITLE_FOR]-(b);

LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_scalesreference.csv' WITH HEADER AS row 
MERGE (scale:ONET_Scale {key: row.scale_id}) ON CREATE SET scale.title = toLower(row.scale_name), scale.min = toInteger(row.minimum), scale.max = toInteger(row.maximum);
 

//print("Add ONET Occupation nodes")
//# Use occupations to identify various jobs - most useful when combined with information about skills. 
//# Each **Occupation** node has a description which provides additional vocabulary and a code that is an easy way to match in the ONET occupation hierarchy. 
 
 
LOAD CSV FROM '/usr/lib/memgraph/import/onet/trusted_occupationdata.csv' WITH HEADER AS row  
MERGE (a:ONET_Occupation {key: row.onet_soc_code, title: toLower(row.title)}) ON CREATE SET a.description = toLower(row.description); 

//print("Add detailed ONET Occupation nodes - just add new unique occupations and relate to existing ones")
//# Added ONET_Occupation nodes are detailed occupations of existing ONET_Occupation nodes -- these relate to each other through a DETAIL_OF relationship.
//# Use: hierarchy of general and detailed occupations provides insight into how occupations might branch into focuses. Also, provides additional vocabulary.
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_detailed.csv' WITH HEADER AS row  
WITH split(row.onet_soc_2019_code, '.') AS soc_id, row
MATCH (a:ONET_Occupation {key: soc_id[0]+'.00'})
MERGE (b:ONET_Occupation {key: soc_id[0]+'.'+soc_id[1]})
ON CREATE SET b.title = toLower(row.onet_soc_2019_title), b.description = toLower(row.onet_soc_2019_description)
WITH a, b
WHERE a.key <> b.key
MERGE (a)<-[:DETAIL_OF]-(b);
        
//# check
MATCH p=(a:ONET_Occupation)<-[:DETAIL_OF]-(b:ONET_Occupation)
WITH split(a.key, '.') AS parent_id, split(b.key, '.') AS child_id, p
WHERE parent_id[1] = '00' AND child_id[1] <> '00' AND parent_id[0] = child_id[0]
RETURN count(p) AS num;

//print("Add additional ONET occupations that are alternate titles for existing occupation nodes")
//# ONET_Occupation nodes connect through the ALT_TITLE_FOR relationship.
//# Use: help find occupations when having trouble matching the exact title + provide additional vocabulary
 
LOAD CSV FROM '/usr/lib/memgraph/import/onet/trusted_alternatetitles.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MERGE (b:ONET_Occupation {title: toLower(row.alternate_title)})
WITH a, b, row
MERGE (a)<-[:ALT_TITLE_FOR]-(b);
        
//# check
MATCH n=(:ONET_Occupation)-[:ALT_TITLE_FOR]-(:ONET_Occupation) RETURN count(n) AS num;

// print("Create occupation groups")
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_soc_structure.csv' WITH HEADER AS row  
WHERE row.major_group<>'' MERGE (a:ONET_Major_Group {key: row.major_group});
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_soc_structure.csv' WITH HEADER AS row  
WHERE row.minor_group<>'' MERGE (a:ONET_Minor_Group {key: row.minor_group}); 
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_soc_structure.csv' WITH HEADER AS row  
WHERE row.broad_occupation<>'' MERGE (a:ONET_Broad_Occupation_Group {key: row.broad_occupation}); 

LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_soc_structure.csv' WITH HEADER AS row  
WHERE row.detailed_occupation<>'' MERGE (a:ONET_Detailed_Occupation_Group {key: row.detailed_occupation}); 
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_soc_structure.csv' WITH HEADER AS row  
MATCH (a:ONET_Major_Group {key: row.major_group})
MATCH (b:ONET_Minor_Group {key: row.minor_group})
MATCH (c:ONET_Broad_Occupation_Group {key: row.broad_occupation})
MATCH (d:ONET_Detailed_Occupation_Group {key: row.detailed_occupation})
MERGE (a)<-[:IN_GROUP]-(b)
MERGE (b)<-[:IN_GROUP]-(c)
MERGE (c)<-[:IN_GROUP]-(d)

// Split the above query into 2. The last Merge was causing a memory issue 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_soc_structure.csv' WITH HEADER AS row  
MATCH (d:ONET_Detailed_Occupation_Group {key: row.detailed_occupation})
MATCH (e:ONET_Occupation {title: toLower(row.soc_or_onet_soc_2019_title)})
MERGE (d)<-[:IN_GROUP]-(e)

MATCH p=(:ONET_Major_Group)<-[:IN_GROUP]-(:ONET_Minor_Group)<-[:IN_GROUP]-(:ONET_Broad_Occupation_Group)<-[:IN_GROUP]-(:ONET_Detailed_Occupation_Group)<-[:IN_GROUP]-(:ONET_Occupation) 
RETURN count(p) AS num;

//print( LOAD ONET elements (aka KSATTs) and establish a hierarchy based on keys.")
//# Use: hierarchy of KSATTs
//# Hierarchy established through SUB_ELEMENT_OF relationship to other **ONET_Element** nodes - check out with:
//# MATCH p=(:ONET_Element {key: '0'})<-[:SUB_ELEMENT_OF]-(b)<-[:SUB_ELEMENT_OF]-(c)<-[:SUB_ELEMENT_OF]-(d) return p limit 50
//# The "leaf" nodes — e.g. **ONET_Element** nodes that are the most detailed in the hierarchy — are re-labeled with their appropriate category.
//# load the elements with key, title and description properties 
 
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_contentmodelreference.csv' WITH HEADER AS row  
MERGE (a:ONET_Element {key: row.element_id})
ON CREATE SET a.title = toLower(row.element_name), a.description = toLower(row.description);
        
  
//# relate elements with the SUB_ELEMENT_OF relationship that have key's like 1.A.1 and 1.A.1.a
 
    MATCH (a:ONET_Element), (b:ONET_Element)
    WHERE b.key CONTAINS a.key AND a.key <> b.key AND size(b.key)-2 = size(a.key)
    MERGE (a)<-[:SUB_ELEMENT_OF]-(b);
 
//# rename lower-level nodes if they match another element node with a shorter key
 
    MATCH (a:ONET_Element), (b:ONET_Element)
    WHERE a.title = b.title AND size(a.key) < size(b.key)
    SET a.title = a.title+' category';
 
//# relate main ONET_Element nodes (with keys 1-6) to the new central Element node (key 0)
MATCH (a:ONET_Element {{key: '{}'}}) 
MERGE (b:ONET_Element {{key: '0', title: 'Element'}}) 
MERGE (b)<-[:SUB_ELEMENT_OF]-(a);


//# get title of ONET_Element node
//# assign label of those sub elements as that title, but only go down so far (to Abilities, Basic Skills, etc. level)
titles = [ t for t in  MATCH (:ONET_Element {key: '0'})<-[:SUB_ELEMENT_OF]-(a:ONET_Element) RETURN a.title AS title ['title']]
for title in titles:
    num_sub =  MATCH (a {{title: "{}"}})<-[:SUB_ELEMENT_OF]-(b:ONET_Element) WHERE size(b.key) < 6 RETURN count(b) AS num""".format(title))['num'][0]
    if num_sub > 0:
        label = title.title().replace(' ', '_').replace('-', '_').replace(',', '_').replace(':', '_')
        new_titles = [ t for t in  
            MATCH (a {{title: "{}"}})<-[:SUB_ELEMENT_OF]-(b:ONET_Element)
            WHERE size(b.key) < 6
            SET b:ONET_{} REMOVE b:ONET_Element
            RETURN b.title AS title
 "".format(title, label))['title']]
        for nt in new_titles:
            titles.append(nt)

# picking up at the nodes we stopped at, assign specific labels further down
num_left =  MATCH (a)<-[:SUB_ELEMENT_OF]-(n:ONET_Element) WHERE a.key <> '0' RETURN count(n) AS num ['num'][0]
while num_left > 0:
    for title in titles:
        label = title.title().replace(' ', '_').replace('-', '_').replace(',', '_').replace(':', '_')
        print(label)
         MATCH (:ONET_{})<-[:SUB_ELEMENT_OF]-(b:ONET_Element) SET b:ONET_{} REMOVE b:ONET_Element""".format(label, label))
    num_left =  MATCH (a)<-[:SUB_ELEMENT_OF]-(n:ONET_Element) WHERE a.key <> '0' RETURN count(n) AS num ['num'][0]
    print(num_left)

//# NOTE
//# we don't really end up using
//# Experience and Training
//# Basic Skills Entry Requirement
//# Cross Functional Skills Entry Requirement
//# Licensing
//# Organizational Context 
//# Titles
//# Description
//# Alternate Titles
//# Labor Market Information
//# Occupational Outlook

MATCH p=(:ONET_Element {key: '0'})<-[:SUB_ELEMENT_OF]-(:ONET_Element {key: '1'}) RETURN count(p) AS num ['num'][0]
if results != 1:
    interrupt("ONET_Element relationships  "there should be relationships between element 0 and 1..6")

MATCH p=(a {key: '1.A.1'})<-[:SUB_ELEMENT_OF]-(b {key: '1.A.1.a'}) RETURN count(p) AS num ['num'][0]
if results != 1:
    interrupt("ONET_Element relationships  "there should be relationships between elements with 'sub-codes'")

MATCH p=(:ONET_Element)<-[:SUB_ELEMENT_OF]-(:ONET_Worker_Characteristics)<-[:SUB_ELEMENT_OF]-(:ONET_Abilities)<-[:SUB_ELEMENT_OF]-(:ONET_Abilities) RETURN count(p) AS num;

// print("Delineate which Commodity nodes are Technology Skills and Tools")
//# Use: specify the technologies and tools in the database for reference of specific skill types.
//# Some **ONET_Commodity** nodes are in fact technologies or tools. So after the **ONET_Commodity** nodes are created, we additionally label those **ONET_Commodity** nodes as **ONET_Technology_Skills** and **ONET_Tools** nodes — _so these have multiple labels_ - depending on which are in technologyskills.csv and toolsused.csv. 
//# **ONET_Technology_Skills** nodes have a trending_technology property to indicate if ONET determines it is a rising skill or not
//# **ONET_Technology_Skills** and **ONET_Tools** are related to their parent **ONET_Occupation_Specific_Information** nodes. 
//# We do not remove the **ONET_Commodity**'s previously created relationship to **ONET_Class**.

//# technology skills
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_technologyskills.csv' WITH HEADER AS row  
MERGE (a:ONET_Technology_Skills {key: row.commodity_code})
ON MATCH SET a:ONET_Commodity
ON CREATE SET a:ONET_Commodity, a.title = toLower(row.commodity_title), a.trending_technology = row.hot_technology
MERGE (b:ONET_Technology_Skills_Example {title: toLower(row.example)})
ON CREATE SET b.trending_technology = row.hot_technology
MERGE (a)<-[:EXAMPLE_OF]-(b);
 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_technologyskills.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation_Specific_Information {key:'5.F'}), (b:ONET_Technology_Skills {key: row.commodity_code})
MERGE (a)<-[:SUB_ELEMENT_OF]-(b);


//# tools
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_toolsused.csv' WITH HEADER AS row  
MERGE (a:ONET_Tools {key: row.commodity_code})
ON MATCH SET a:ONET_Commodity
ON CREATE SET a:ONET_Commodity, a.title = toLower(row.commodity_title)
MERGE (b:ONET_Tools_Example {title: toLower(row.example)})
MERGE (a)<-[:EXAMPLE_OF]-(b);
 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_toolsused.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation_Specific_Information {key:'5.G'}), (b:ONET_Tools {key: row.commodity_code})
MERGE (a)<-[:SUB_ELEMENT_OF]-(b);

//print("Create a hierarchical pattern of Segment, Family, Class and Commodity nodes")

// Hierarchy created from Segment <- Family <- Class <- Commodity
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_unspscreference.csv' WITH HEADER AS row  
MERGE (a:ONET_Segment {key: row.segment_code})
SET a.title = toLower(row.segment_title)
MERGE (b:ONET_Family {key: row.family_code})
SET b.title = toLower(row.family_title)
MERGE (c:ONET_Class {key: row.class_code})
SET c.title = toLower(row.class_title)
MERGE (d:ONET_Commodity {key: row.commodity_code})
MERGE (a)<-[:SUB_SEGMENT_OF]-(b)
MERGE (b)<-[:SUB_SEGMENT_OF]-(c)
MERGE (c)<-[:SUB_SEGMENT_OF]-(d)
 

//print("Check that the Commodity hierachy and Technology Skills/Tools queries completed as expected")
//check_queries = []
MATCH p=(:ONET_Technology_Skills)--(:ONET_Technology_Skills_Example) RETURN count(p) AS num 
MATCH p=(:ONET_Tools)--(:ONET_Tools_Example) RETURN count(p) AS num 
MATCH (a) WHERE a:ONET_Commodity AND a:ONET_Technology_Skills RETURN count(a) AS num 
MATCH (a) WHERE a:ONET_Commodity AND a:ONET_Tools RETURN count(a) AS num 
MATCH p=(:ONET_Segment)<-[:SUB_SEGMENT_OF]-(:ONET_Family)<-[:SUB_SEGMENT_OF]-(:ONET_Class)<-[:SUB_SEGMENT_OF]-(:ONET_Commodity) RETURN count(p) AS num 
MATCH p=(:ONET_Segment)<-[:SUB_SEGMENT_OF]-(:ONET_Family)<-[:SUB_SEGMENT_OF]-(:ONET_Class)<-[:SUB_SEGMENT_OF]-(:ONET_Technology_Skills) RETURN count(p) AS num 
MATCH p=(:ONET_Segment)<-[:SUB_SEGMENT_OF]-(:ONET_Family)<-[:SUB_SEGMENT_OF]-(:ONET_Class)<-[:SUB_SEGMENT_OF]-(:ONET_Tools) RETURN count(p) AS num 
MATCH p=(a:ONET_Occupation_Specific_Information {key:'5.F'})<-[:SUB_ELEMENT_OF]-(b:ONET_Technology_Skills) RETURN count(p) AS num 
MATCH p=(a:ONET_Occupation_Specific_Information {key:'5.G'})<-[:SUB_ELEMENT_OF]-(b:ONET_Tools) RETURN count(p) AS num 

//print("Create a hierarchy of work activities (generalized, intermediate, detailed)")
//# Use: be able to look at work activities at different levels of granularity
//# **ONET_Generalized_Work_Activities** were already created from the contentmodelreference.csv (all **ONET_Element** nodes that started as 4.A were re-labeled as **ONET_Generalized_Work_Activities**)
//# Intermediate & Detailed were not detailed in contentmodelreference.csv but are in this document, so we're creating these
//# **ONET_Generalized_Work_Activities** <- **ONET_Intermediate_Work_Activities** <- **ONET_Detailed_Work_Activities**
//# **ONET_Intermediate_Work_Activities** and **ONET_Detailed_Work_Activities** are related to their parents in the element hierarchy

//# Generalized_Work_Activities were already created from contentmodelreference.csv, so we need to match those
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_dwareference.csv' WITH HEADER AS row  

MATCH (a:ONET_Generalized_Work_Activities {key: row.element_id})
MATCH (bb:ONET_Occupational_Requirements {title:'intermediate work activities'})
MATCH (cc:ONET_Occupational_Requirements {title:'detailed work activities'})
MERGE (b:ONET_Intermediate_Work_Activities {key: row.iwa_id, title: toLower(row.iwa_title)})
MERGE (c:ONET_Detailed_Work_Activities {key: row.dwa_id, title: toLower(row.dwa_title)})

MERGE (a)<-[:DETAIL_OF]-(b)
MERGE (b)<-[:DETAIL_OF]-(c)
MERGE (bb)<-[:SUB_ELEMENT_OF]-(b)
MERGE (cc)<-[:SUB_ELEMENT_OF]-(c)

//check_queries = []

MATCH p=(:ONET_Occupational_Requirements)<-[:SUB_ELEMENT_OF]-(:ONET_Generalized_Work_Activities) RETURN count(p) AS num 
MATCH p=(:ONET_Occupational_Requirements)<-[:SUB_ELEMENT_OF]-(:ONET_Intermediate_Work_Activities) RETURN count(p) AS num 
MATCH p=(:ONET_Occupational_Requirements)<-[:SUB_ELEMENT_OF]-(:ONET_Detailed_Work_Activities) RETURN count(p) AS num 
MATCH p=(:ONET_Generalized_Work_Activities)<-[:DETAIL_OF]-(:ONET_Intermediate_Work_Activities)<-[:DETAIL_OF]-(:ONET_Detailed_Work_Activities) RETURN count(p) AS num 

//print("Create task nodes")
//# Use: different tasks performed as part of occupations or work activities imply skills, which we are interested in
//# These were not included in contentmodelreference.csv, only the parent Tasks **ONET_Element** node was, so this loads detailed **ONET_Tasks** nodes
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_taskstatements.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation_Specific_Information {title: 'tasks'})
MERGE (b:ONET_Tasks {title: toLower(row.task)})
ON CREATE SET b.key = row.task_id, b.description = toLower(row.task), b.type = toLower(row.task_type)
ON MATCH SET b.key = row.task_id+', '+b.key
MERGE (a)<-[:SUB_ELEMENT_OF]-(b); 

MATCH p=(:ONET_Occupation_Specific_Information {title: 'tasks'})<-[:SUB_ELEMENT_OF]-(:ONET_Tasks) RETURN count(p) AS num; 

//print("Match tasks to detailed work activities")
//# Because **ONET_Tasks** are required in order to complete work activities, we want to associate **ONET_Detailed_Work_Activities** with requisite **ONET_Tasks**.
//# We don't create any nodes, we just MATCH existing **ONET_Tasks** and **ONET_Detailed_Work_Activities** nodes.
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_taskstodwas.csv' WITH HEADER AS row  
MATCH (a:ONET_Detailed_Work_Activities {key: row.dwa_id})
MATCH (b:ONET_Tasks {title: toLower(row.task)})
WITH a, b, row
MERGE (a)<-[:TASK_FOR_DWA]-(b); 

MATCH p=(:ONET_Detailed_Work_Activities)<-[:TASK_FOR_DWA]-(:ONET_Tasks) RETURN count(p) AS num;

//print("Enrich the existing education and experiences and training data by adding categories")

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_educationtrainingandexperiencecategories.csv' WITH HEADER AS row  
MATCH (a:ONET_Education {key: row.element_id})
MERGE (b:ONET_Education_Category {key: row.scale_id+'.'+row.category, title: toLower(row.category_description)})
MERGE (a)<-[:CATEGORY_OF]-(b); 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_educationtrainingandexperiencecategories.csv' WITH HEADER AS row  
MATCH (a:ONET_Experience_And_Training {key: row.element_id})
MERGE (b:ONET_Experience_And_Training_Category {key: row.scale_id+'.'+row.category, title: toLower(row.category_description)})
MERGE (a)<-[:CATEGORY_OF]-(b); 


MATCH p=(:ONET_Education)<-[:CATEGORY_OF]-(:ONET_Education_Category) RETURN count(p) AS num 
MATCH p=(:ONET_Experience_And_Training)<-[:CATEGORY_OF]-(:ONET_Experience_And_Training_Category) RETURN count(p) AS num [

MATCH p=(:ONET_Education)<-[:CATEGORY_OF]-(:ONET_Education_Category)-[:CATEGORY_OF]->(:ONET_Education) RETURN count(p) AS num 
MATCH p=(:ONET_Experience_And_Training)<-[:CATEGORY_OF]-(:ONET_Experience_And_Training_Category)-[:CATEGORY_OF]->(:ONET_Experience_And_Training) RETURN count(p) AS num 

//print("Create relationships between occupations and the various KSATTs derived from ONET")
//# 1.  All KSATT nodes were originally **ONET_Element** nodes, they were just re-labeled. So they all have an id and title, and _SUB_ELEMENT_OF_ relationship. These are not being created, only matched.
//# 2.  Now they all will have relationships with **ONET_Occupation** nodes - these are _FOUND_IN_ relationships at the core, but are named differently based on the type of scale that the relationship indicates (e.g. _LV_FOUND_IN_ for level, _IM_FOUND_IN_ for importance, etc.). These will be cleaned up later.

// ######################## NEED TO LOOK INTO APOC.MERGE ############################### 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_abilities.csv'V WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Abilities {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_interests.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Interests_And_Work_Values {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:1000}) YIELD * RETURN *; 


 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_workstyles.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Work_Styles {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:1000}) YIELD * RETURN *; 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_skills.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Basic_Skills {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_skills.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Cross_Functional_Skills {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_knowledge.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Knowledge {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_educationtrainingandexperience.csv' WITH HEADER AS row  

MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Education_Category {key: row.scale_id+'.'+row.category})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

 
LOAD CSV FROM '/usr/lib/memgraph/import/onet/trusted_educationtrainingandexperience.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Experience_And_Training_Category {key: row.scale_id+'.'+row.category})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

//# here the GWAs are being matched but really we associated the DWA with the Occupations
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_workactivities.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Generalized_Work_Activities {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_workcontext.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Work_Context {key: row.element_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:1000}) YIELD * RETURN *; 

 

MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Tasks {key: row.task_id})
WITH a, b, row
CALL apoc.merge.relationship(b, toString(row.scale_id)+'_FOUND_IN', {data_value: toFloat(row.data_value)}, {}, a, {}) YIELD rel RETURN rel
 {batch_size:10000}) YIELD * RETURN *; 

//# TODO: no weights 
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_technologyskills.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Technology_Skills {key: row.commodity_code})
WITH a, b, row
MERGE (b)-[:FOUND_IN]->(a)
 {batch_size:10000}) YIELD * RETURN *; 

//# TODO: no weights 
 
LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_toolsused.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation {key: row.onet_soc_code})
MATCH (b:ONET_Tools {key: row.commodity_code})
WITH a, b, row
MERGE (b)-[:FOUND_IN]->(a)
 {batch_size:10000}) YIELD * RETURN *; 


//check_queries = []

MATCH p=(:ONET_Occupation)<--(:ONET_Abilities) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Interests_And_Work_Values) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Work_Styles) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Basic_Skills) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Cross_Functional_Skills) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Education_Category) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Experience_And_Training_Category) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Generalized_Work_Activities) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Work_Context) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Tasks) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Technology_Skills) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<--(:ONET_Tools) RETURN count(p) AS num

// #######################################################

// ###################################################### Look into
//print("Clean FOUND_IN relationships")
//# gather all the different types of FOUND_IN relationships
relationships = [x['rel'] for x in graph.run("""MATCH (a)-[r]-(b) WHERE type(r) CONTAINS 'FOUND_IN' RETURN DISTINCT type(r) AS rel .data()]
# convert all the different types of FOUND_IN relationships to a FOUND_IN relationship with a normalized property of it's type instead
# e.g. IM Scale from 1 to 10 | IM_FOUND_IN {data_value: 7} -> FOUND_IN {IM: 0.7}
for r in relationships:
    if r != 'FOUND_IN':
        prefix = r.replace('_FOUND_IN', '')
        print(prefix)
        graph.run("""
            CALL {{MATCH (a:ONET_Scale {{key: '{}'}}) RETURN a.max AS max LIMIT 1}}
            WITH max
            MATCH (a)<-[r1:{}_FOUND_IN]-(b) MERGE (a)<-[r2:FOUND_IN]-(b) SET r2.{} = toFloat(r1.data_value)/max
 "".format(prefix, prefix, prefix))
        graph.run("""MATCH (a)<-[r1:{}_FOUND_IN]-(b) DELETE r1""".format(prefix))
check_queries = []
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Abilities) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Interests_And_Work_Values) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Work_Styles) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Basic_Skills) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Cross_Functional_Skills) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Education_Category) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Experience_And_Training_Category) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Generalized_Work_Activities) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Work_Context) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Tasks) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Technology_Skills) RETURN count(p) AS num 
MATCH p=(:ONET_Occupation)<-[:FOUND_IN]-(:ONET_Tools) RETURN count(p) AS num 
//for cq in check_queries:
//    results = run_reg_query(cq)['num'][0]
//    if results <= 0:
//        interrupt("Relationships between ONET Occupations and KSATTs  "there should be relationships")
//results = [item['rel'] for item in graph.run("""
MATCH (a)-[r]-(b) WHERE type(r) CONTAINS 'FOUND_IN' RETURN DISTINCT type(r) AS rel
//print(results)
//if len(results) > 1 or 'FOUND_IN' not in results:
//    interrupt("FOUND_IN relationship cleaning  "only FOUND_IN relationship left should be not prefixxed by anything")

// ###################################################################

// UPLOAD ESCO DATA Notes:
// concept_Schemes didn't have anything helpful.  
// Everything from ictSkills was in transversalSkillsCollection.

//print("Add skill, knowledge, language, and attitudes and value hierarchy")

//# add skill hierarchy 
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_skillshierarchy_en.csv' WITH HEADER AS row  
WHERE row.level_3_code <> '' AND row.level_0_preferred_term = 'skills'
MERGE (a:ESCO_Skills {uri: row.level_1_uri})
ON CREATE SET a.title = row.level_1_preferred_term
MERGE (b:ESCO_Skills {uri: row.level_2_uri})
ON CREATE SET b.title = row.level_2_preferred_term
MERGE (c:ESCO_Skills {uri: row.level_3_uri})
ON CREATE SET c.title = row.level_3_preferred_term, c.description = row.description

MERGE (a)<-[:SUB_ELEMENT_OF]-(b)
MERGE (b)<-[:SUB_ELEMENT_OF]-(c); 

//# add knowledge hierarchy
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_skillshierarchy_en.csv' WITH HEADER AS row  
WHERE row.level_3_preferred_term <> '' AND row.level_0_preferred_term = 'knowledge'
MERGE (a:ESCO_Knowledge {uri: row.level_1_uri})
ON CREATE SET a.title = row.level_1_preferred_term
MERGE (b:ESCO_Knowledge {uri: row.level_2_uri})
ON CREATE SET b.title = row.level_2_preferred_term
MERGE (c:ESCO_Knowledge {uri: row.level_3_uri})
ON CREATE SET c.title = row.level_3_preferred_term

MERGE (a)<-[:SUB_ELEMENT_OF]-(b)
MERGE (b)<-[:SUB_ELEMENT_OF]-(c)
WITH c, row
WHERE row.description <> ''
SET c.description = row.description; 

//# add language hierarchy
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_skillshierarchy_en.csv' WITH HEADER AS row  
WHERE row.level_1_code <> '' AND row.level_0_preferred_term = 'language skills and knowledge'
MERGE (a:ESCO_Language {uri: row.level_1_uri})
ON CREATE SET a.title = row.level_1_preferred_term, a.description = row.description; 

//# add attitudes and values hierarchy 
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_skillshierarchy_en.csv' WITH HEADER AS row  
WHERE row.level_3_code <> '' AND row.level_0_preferred_term = 'attitudes and values'
MERGE (a:ESCO_Attitudes_Values {uri: row.level_1_uri})
ON CREATE SET a.title = row.level_1_preferred_term
MERGE (b:ESCO_Attitudes_Values {uri: row.level_2_uri})
ON CREATE SET b.title = row.level_2_preferred_term
MERGE (c:ESCO_Attitudes_Values {uri: row.level_3_uri})
ON CREATE SET c.title = row.level_3_preferred_term, c.description = row.description

MERGE (a)<-[:SUB_ELEMENT_OF]-(b)
MERGE (b)<-[:SUB_ELEMENT_OF]-(c); 

//check_queries = []
MATCH p=(:ESCO_Skills)<-[:SUB_ELEMENT_OF]-(:ESCO_Skills)<-[:SUB_ELEMENT_OF]-(:ESCO_Skills) RETURN count(p) AS num 
MATCH p=(:ESCO_Knowledge)<-[:SUB_ELEMENT_OF]-(:ESCO_Knowledge)<-[:SUB_ELEMENT_OF]-(:ESCO_Knowledge) RETURN count(p) AS num 
MATCH (a:ESCO_Language) RETURN count(a) AS num 
MATCH p=(:ESCO_Attitudes_Values)<-[:SUB_ELEMENT_OF]-(:ESCO_Attitudes_Values)<-[:SUB_ELEMENT_OF]-(:ESCO_Attitudes_Values) RETURN count(p) AS num 

MATCH (a:ESCO_Skills) RETURN count(a) AS num [
MATCH (a:ESCO_Knowledge) RETURN count(a) AS num 
MATCH (a:ESCO_Language) RETURN count(a) AS num 
MATCH (a:ESCO_Attitudes_Values) RETURN count(a)

//print("Add additional skills to the hierarchy")

 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_transversalskillscollection_en.csv' WITH HEADER AS row  
WHERE row.skillType = 'skill/competence' 
WITH split(row.broaderconceptpt, ' | ') AS broaderconcepttitles, split(row.broaderconcepturi, ' | ') AS broaderconcepturis, row
MERGE (a:ESCO_Skills {uri: broaderconcepturis[0]})
ON CREATE SET a.title = broaderconcepttitles[0]
MERGE (b:ESCO_Skills {uri: broaderconcepturis[1]})
ON CREATE SET b.title = broaderconcepttitles[1]
MERGE (c:ESCO_Skills {uri: row.conceptUri})
ON CREATE SET c.title = row.preferredlabel, c.alt_labels = row.altlabels, c.description = row.description

MERGE (a)<-[:SUB_ELEMENT_OF]-(c)
MERGE (b)<-[:SUB_ELEMENT_OF]-(c); 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_transversalskillscollection_en.csv' WITH HEADER AS row  
WHERE row.skillType = 'knowledge' 
WITH split(row.broaderconceptpt, ' | ') AS broaderconcepttitles, split(row.broaderconcepturi, ' | ') AS broaderconcepturis, row
MERGE (a:ESCO_Knowledge {uri: broaderconcepturis[0]})
ON CREATE SET a.title = broaderconcepttitles[0]
MERGE (b:ESCO_Knowledge {uri: broaderconcepturis[1]})
ON CREATE SET b.title = broaderconcepttitles[1]
MERGE (c:ESCO_Knowledge {uri: row.conceptUri})
ON CREATE SET c.title = row.preferredlabel, c.alt_labels = row.altLabels, c.description = row.description

MERGE (a)<-[:SUB_ELEMENT_OF]-(c)
MERGE (b)<-[:SUB_ELEMENT_OF]-(c); 

//# prev_num_skills = num_skills
//# num_skills = run_query("""MATCH (a:ESCO_Skills) RETURN count(a) AS num ['num'][0]
//# if num_skills <= prev_num_skills:
//#     interrupt("Additional ESCO Skills  "there should have been more ESCO Skills created")

//# prev_num_knowledge = num_knowledge
//# num_knowledge = run_query("""MATCH (a:ESCO_Knowledge) RETURN count(a) AS num ['num'][0]
//# if num_knowledge <= prev_num_knowledge:
//#     interrupt("Additional ESCO Knowledge  "there should have been more ESCO Skills created")

//print("Add languages to the hierarchy")

 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_languageskillscollection_en.csv' WITH HEADER AS row  
WHERE row.broaderconceptpt CONTAINS 'languages'
MATCH (a:ESCO_Language {title: 'languages'})
MERGE (b:ESCO_Language {uri: row.concepturi})
ON CREATE SET b.title = row.preferredlabel, b.alt_labels = row.altlabels, b.description = row.description

MERGE (a)<-[:SUB_ELEMENT_OF]-(c); 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_languageskillscollection_en.csv' WITH HEADER AS row  
WHERE row.broaderconceptpt <> 'languages | language' AND row.broaderconceptpt <> 'language | languages'
MATCH (a:ESCO_Language {title: row.broaderconceptpt})
MERGE (b:ESCO_Language {uri: row.concepturi})
ON CREATE SET b.title = row.preferredlabel, b.alt_labels = row.altlabels, b.description = row.description

MERGE (a)<-[:SUB_ELEMENT_OF]-(b) 

//# check_queries = []
//# MATCH p=(:ESCO_Language {title: 'languages'})<-[:SUB_ELEMENT_OF]-(:ESCO_Language) RETURN count(p) AS num 
//# MATCH p=(:ESCO_Language)<-[:SUB_ELEMENT_OF]-(:ESCO_Language) RETURN count(p) AS num 
//# for cq in check_queries:
//#     results = run_query(cq)['num'][0]
//#     if results <= 1:
//#         interrupt("Additional ESCO KSATTs  "there should be more ESCO KSATTs or relationships between them")

//# prev_num_language = num_language
//# num_language = run_query("""MATCH (a:ESCO_Language) RETURN count(a) AS num ['num'][0]
//# if num_language <= prev_num_language:
//#     interrupt("Additional ESCO Languages  "there should have been more ESCO Languages created")

//print("Add additional skills and knowledge")
//# TODO: These don't really connect to any other parts of the hierarchy as far as I could figure out.

//# add other skills
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_skills_en.csv' WITH HEADER AS row  
WHERE row.skilltype = 'skill/competence'
MERGE (a:ESCO_Skills {uri: row.concepturi})
ON CREATE SET a.title = row.preferredlabel, a.alt_title = row.altlabels, a.description = row.description; 

//# add other knowledge
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_skills_en.csv' WITH HEADER AS row  
WHERE row.skilltype = 'knowledge'
MERGE (a:ESCO_Knowledge {uri: row.concepturi})
ON CREATE SET a.title = row.preferredlabel, a.alt_title = row.altlabels, a.description = row.description; 

//# prev_num_skills = num_skills
//# num_skills = run_query("""MATCH (a:ESCO_Skills) RETURN count(a) AS num ['num'][0]
//# if num_skills <= prev_num_skills:
//#     interrupt("Additional ESCO Skills  "there should have been more ESCO Skills created")

//# prev_num_knowledge = num_knowledge
//# num_knowledge = run_query("""MATCH (a:ESCO_Knowledge) RETURN count(a) AS num ['num'][0]
//# if num_knowledge <= prev_num_knowledge:
//#     interrupt("Additional ESCO Knowledge  "there should have been more ESCO Skills created")

//print("Remove circular relationships AND add IDs based off of URIs")
//esco_labels = ['ESCO_Skills', 'ESCO_Knowledge', 'ESCO_Language', 'ESCO_Attitudes_Values']
//for el in esco_labels:
 MATCH (a:{})-[r:SUB_ELEMENT_OF]-(a) DELETE r RETURN count(r) AS num
//    print("Deleted  results, "relationships.")
     
MATCH (a:{})
WITH split(a.uri, '/')[5] AS id_from_uri, a
SET a.key = id_from_uri

//print("Create occupations and groups")
//# create occupation groups - don't relate them yet
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_iscogroups_en.csv' WITH HEADER AS row  
WITH row, split(row.concepturi, 'C')[1] AS code
MERGE (a:ESCO_Occupation_Group {uri: row.concepturi})
ON CREATE SET a.key = code, a.title = row.preferredlabel, a.alt_labels = row.altlabels, a.description = row.description; 

//### WHAT THIS DOES ###
//# find occupation groups where 
//    # parent and child ids are not the same (e.g. 12, 121, 1213)
//    # parent id is one less number in length than the child id (e.g. 12 is one number shorter than 121, same for 121 and 1213)
//   # the parent id and a substring of the child id match
//        # the substring of the child id starts at the first number in the id and is the length of the parent id
//        # so in effect it's matching the substring of the child id that should be equal to the parent id 
//        # e.g. 1213 child, 121 parent -> 1213 starts at first '1' and goes through '121' because that's the length of the parent 121
//# create a relationship where the parent and child ids match up
 
MATCH (a:ESCO_Occupation_Group), (b:ESCO_Occupation_Group)
WHERE a.key <> b.key AND size(b.key)-1 = size(a.key) AND a.key = substring(b.key, 0, size(a.key))
MERGE (a)<-[:SUB_ELEMENT_OF]-(b)
 

//# create occupations and assign them to occupation groups
 
LOAD CSV FROM  '/usr/lib/memgraph/import/esco/trusted_occupations_en.csv' WITH HEADER AS row  
MATCH (a:ESCO_Occupation_Group {key: row.iscogroup})
MERGE (b:ESCO_Occupation {uri: row.concepturi})
SET b.title = row.preferredlabel, b.alt_labels = row.altlabels, b.description = row.description, b.key = row.code
MERGE (a)<-[:IN_GROUP]-(b); 

 
MATCH (a:ESCO_Occupation), (b:ESCO_Occupation)
WHERE a.key <> b.key AND (size(b.key)-2 = size(a.key) OR size(b.key)-3 = size(a.key)) AND a.key = substring(b.key, 0, size(a.key))
MERGE (a)<-[:SUB_ELEMENT_OF]-(b)
 
// Check relationships
MATCH p=(a:ESCO_Occupation_Group)<--(b:ESCO_Occupation_Group) WHERE a.key<>b.key AND size(b.key)-1 = size(a.key) AND b.key CONTAINS a.key RETURN count(p) AS num 
MATCH p=(:ESCO_Occupation_Group)<--(:ESCO_Occupation_Group)<--(:ESCO_Occupation_Group)<--(:ESCO_Occupation_Group)<--(:ESCO_Occupation)<--(:ESCO_Occupation)<--(:ESCO_Occupation)<--(:ESCO_Occupation) RETURN count(p) AS num


MATCH (a:ESCO_Occupation) WHERE NOT (:ESCO_Occupation)<--(a) AND NOT (:ESCO_Occupation_Group)<--(a) RETURN count(a) AS num

// UPLAOD NICE Data

//print("Use table of contents to establish and relate NICE Categories, Areas and Workroles")

 
LOAD CSV FROM  '/usr/lib/memgraph/import/nice/trusted_nice_areas_and_roles.csv' WITH HEADER AS row  
MERGE (a:NICE_Category {title: toLower(row.nice_category_title), acronym: row.nice_category_acronym, description: toLower(row.nice_category_description)});
 
LOAD CSV FROM  '/usr/lib/memgraph/import/nice/trusted_nice_areas_and_roles.csv' WITH HEADER AS row  
MERGE (a:NICE_Area {title: toLower(row.nice_specialty_area_title), acronym: row.nice_specialty_area_acronym, description: toLower(row.nice_specialty_area_description)});
 

LOAD CSV FROM  '/usr/lib/memgraph/import/nice/trusted_nice_areas_and_roles.csv' WITH HEADER AS row  
WITH row, split(row.work_role_id, '-') AS work_role_id_components
MERGE (a:NICE_Workrole {key: row.work_role_id, key_1: work_role_id_components[0], key_2: work_role_id_components[1], key_3: work_role_id_components[2], title: toLower(row.work_role), description: toLower(row.work_role_description)})
WITH row, a
MATCH (b:NICE_Area {acronym: a.key_2})
MATCH (c:NICE_Category {acronym: a.key_1})
MERGE (a)-[:IN_AREA]->(b)
MERGE (b)-[:IN_CATEGORY]->(c);
 

 
LOAD CSV FROM  '/usr/lib/memgraph/import/nice/trusted_nice_areas_and_roles.csv' WITH HEADER AS row  
MATCH (a:NICE_Workrole {key: row.work_role_id})
MERGE (b:OPM_Cybersecurity_Category {key: row.opm_code_fed_use})
MERGE (a)-[:IN_CATEGORY]->(b);
 
// Check
MATCH a=(:NICE_Category)<-[:IN_CATEGORY]-(:NICE_Area)<-[:IN_AREA]-(:NICE_Workrole)-[:IN_CATEGORY]->(:OPM_Cybersecurity_Category) RETURN count(a) AS num;

//print("Add NICE KSATTs and relate them to NICE Workroles")
//# add NICE_Tasks and connect to NICE_Workrole nodes
//# don't add KSA id because there are KSAs with the same title but different IDs, and the IDs don't matter (no hierarchy or context)
 
LOAD CSV FROM  '/usr/lib/memgraph/import/nice/trusted_master_ksatt_list_mapped.csv' WITH HEADER AS row  
MATCH (a:NICE_Workrole {key: row.work_role_id})
MERGE (b:NICE_KSAs {title: toLower(row.title)})
ON CREATE SET b.key = row.id
MERGE (b)-[:FOUND_IN]->(a);
 

//# set NICE_KSAs labels to be more specific
MATCH (a:NICE_KSAs) WHERE a.key CONTAINS 'K' SET a:NICE_Knowledge REMOVE a:NICE_KSAs, a.key 
MATCH (a:NICE_KSAs) WHERE a.key CONTAINS 'S' SET a:NICE_Skills REMOVE a:NICE_KSAs, a.key 
MATCH (a:NICE_KSAs) WHERE a.key CONTAINS 'A' SET a:NICE_Abilities REMOVE a:NICE_KSAs, a.key 
MATCH (a:NICE_KSAs) WHERE a.key CONTAINS 'T' SET a:NICE_Tasks REMOVE a:NICE_KSAs, a.key 

// check_queries = []
MATCH a=(:NICE_Knowledge)-[:FOUND_IN]->(:NICE_Workrole) RETURN count(a) AS num 
MATCH a=(:NICE_Skills)-[:FOUND_IN]->(:NICE_Workrole) RETURN count(a) AS num 
MATCH a=(:NICE_Abilities)-[:FOUND_IN]->(:NICE_Workrole) RETURN count(a) AS num 
MATCH a=(:NICE_Tasks)-[:FOUND_IN]->(:NICE_Workrole) RETURN count(a) AS num 

// Crosswalk OPM and ONET

//print("Add in the OPM Series to ONET Occupation Crosswalk")

//# create OPM Series nodes
 
LOAD CSV FROM  '/usr/lib/memgraph/import/trusted_opm_onet_crosswalk.csv' WITH HEADER AS row  
MERGE (:OPM_Series {key: row.opm_series_number, title: row.opm_series_title}); 

//# create relationship between occupations and opm key's if they're in the right row
 
LOAD CSV FROM  '/usr/lib/memgraph/import/trusted_opm_onet_crosswalk.csv' WITH HEADER AS row  
MATCH (a:ONET_Occupation), (b:OPM_Series {key: row.opm_series_number})
WHERE a.key CONTAINS(row.`2010_soc_code`)
MERGE (a)-[r:IN_OPM {census_code: row.`2010_eeo_tabulation_census_code`, census_title: toLower(row.`2010_eeo_tabulation_census_occupation_title`)}]->(b); 

//Check
MATCH a=(:ONET_Occupation)-[:IN_OPM]->(:OPM_Series) RETURN count(a) AS num 

//print("Equate OPM Series to ONET Occupations for specific SOC Codes")

MATCH (a:ONET_Occupation {key: '17-2071.00'}), (b:OPM_Series) WHERE b.key CONTAINS("855")
MERGE (a)-[:IN_OPM {census_code: '1410', census_title: toLower('ELECTRICAL & ELECTRONIC ENGINEERS')}]->(b); 

MATCH (a:ONET_Occupation {key: '17-2072.00'}), (b:OPM_Series) WHERE b.key CONTAINS("855")
MERGE (a)-[:IN_OPM {census_code: '1410', census_title: toLower('ELECTRICAL & ELECTRONIC ENGINEERS')}]->(b); 

MATCH (a:ONET_Occupation), (b:OPM_Series) WHERE a.key CONTAINS('17-206') AND b.key CONTAINS("854")
MERGE (a)-[:IN_OPM {census_code: '1400', census_title: toLower('COMPUTER HARDWARE ENGINEERS')}]->(b); 

//# TODO: was 15-1111 but no SOC codes match that
//# run_query("""MATCH (a:ONET_Occupation), (b:OPM_Series) WHERE a.key CONTAINS('15-1111') AND b.key CONTAINS("1550")
//# MERGE (a)-[:IN_OPM {census_code: '1005', census_title: toLower('COMPUTER & INFORMATION RESEARCH SCIENTISTS')}]->(b); 
MATCH (a:ONET_Occupation), (b:OPM_Series) WHERE a.key CONTAINS('15-1') AND b.key CONTAINS("1550")
MERGE (a)-[:IN_OPM {census_code: '1005', census_title: toLower('COMPUTER & INFORMATION RESEARCH SCIENTISTS')}]->(b); 

MATCH (a:ONET_Occupation), (b:OPM_Series) WHERE a.key CONTAINS('15-1') AND b.key CONTAINS('2210')
MERGE (a)-[:IN_OPM {census_code: '1050', census_title: toLower('COMPUTER SUPPORT SPECIALISTS')}]->(b); 

//print("Check the OPM to ONET Crosswalk queries")

// check_queries = []
MATCH p=(a:ONET_Occupation {key: '17-2071.00'})-[:IN_OPM]->(b:OPM_Series) WHERE b.key CONTAINS("855") RETURN count(p) AS num 
MATCH p=(a:ONET_Occupation {key: '17-2072.00'})-[:IN_OPM]->(b:OPM_Series) WHERE b.key CONTAINS("855") RETURN count(p) AS num 
MATCH p=(a:ONET_Occupation)-[:IN_OPM]->(b:OPM_Series) WHERE a.key CONTAINS('17-206') AND b.key CONTAINS("854") RETURN count(p) AS num 
//# TODO: same here
# MATCH p=(a:ONET_Occupation)-[:IN_OPM]->(b:OPM_Series) WHERE a.key CONTAINS('15-1111') AND b.key CONTAINS("1550") RETURN count(p) AS num 
MATCH p=(a:ONET_Occupation)-[:IN_OPM]->(b:OPM_Series) WHERE a.key CONTAINS('15-1') AND b.key CONTAINS("1550") RETURN count(p) AS num 
MATCH p=(a:ONET_Occupation)-[:IN_OPM]->(b:OPM_Series) WHERE a.key CONTAINS('15-1') AND b.key CONTAINS("2210") RETURN count(p) AS num 