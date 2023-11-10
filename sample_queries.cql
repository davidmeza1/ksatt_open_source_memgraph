//SHOW TRANSACTIONS;
//TERMINATE TRANSACTIONs"9223372036854776500";
//STORAGE MODE IN_MEMORY_TRANSACTIONAL;
//STORAGE MODE IN_MEMORY_ANALYTICAL;
STORAGE MODE ON_DISK_TRANSACTIONAL;
//SHOW STORAGE INFO;
//SHOW CONFIG;

 
 LOAD CSV FROM  '/usr/lib/memgraph/import/onet/trusted_soc_structure.csv' WITH HEADER AS row RETURN row 
 
        //MATCH (a:ONET_Major_Group {key: row.major_group})
        //MATCH (b:ONET_Minor_Group {key: row.minor_group})
        //MATCH (c:ONET_Broad_Occupation_Group {key: row.broad_occupation})
        MATCH (d:ONET_Detailed_Occupation_Group {key: row.detailed_occupation})
        MATCH (e:ONET_Occupation {title: toLower(row.soc_or_onet_soc_2019_title)})

        //MERGE (a)<-[:IN_GROUP]-(b)
        //MERGE (b)<-[:IN_GROUP]-(c)
        //MERGE (c)<-[:IN_GROUP]-(d)
        MERGE (d)<-[:IN_GROUP]-(e)
 ,
    {batch_size:500}) YIELD * RETURN *;