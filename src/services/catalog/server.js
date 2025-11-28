const express  =  require('express');
const  { CosmosClient  }  =  require('@azure/cosmos');

const  endpoint  =  process.env.COSMOS_ENDPOINT;  // Account  endpoint  (automatic  failover)
const key  =  process.env.COSMOS_KEY;
const  databaseId =  process.env.COSMOS_DB  ||  'catalogdb';
const containerId  =  process.env.COSMOS_CONTAINER  ||  'products';

const  app  =  express();
app.use(express.json());

const  client  = new  CosmosClient({  endpoint,  key  });

app.get('/healthz',  (req,  res)  => res.json({  status:  'ok'  }));

app.get('/products',  async  (_req,  res)  => {
    const  { resources  }  =  await  client
       .database(databaseId)
       .container(containerId)
       .items.query('SELECT TOP  50  c.id,  c.name,  c.category FROM  c')
       .fetchAll();
    res.json(resources);
});

app.post('/products',  async  (req, res)  =>  {
   const  {  name,  category  } =  req.body;
    const item  =  {  id:  `${Date.now()}`, name,  category  };
   await  client.database(databaseId).container(containerId).items.create(item);
    res.status(201).json({ status:  'created'  });
});

app.listen(8081,  ()  =>  console.log('Catalog  service listening  on  8081'));
