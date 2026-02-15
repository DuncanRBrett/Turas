import { useState, useMemo } from "react";

const DATA = {"banner_groups":{"Campus":[{"label":"Online campus","letter":"A"},{"label":"Cape Town","letter":"B"},{"label":"Johannesburg","letter":"C"},{"label":"Pretoria","letter":"D"},{"label":"Durban","letter":"E"}],"Year":[{"label":"1st yr","letter":"A"},{"label":"2nd yr","letter":"B"},{"label":"3rd yr","letter":"C"},{"label":"4th yr","letter":"D"},{"label":"Honours","letter":"E"},{"label":"Masters","letter":"F"}],"Age":[{"label":"18 - 20 years","letter":"A"},{"label":"21 - 24 years","letter":"B"},{"label":"25 - 34 years","letter":"C"},{"label":"35 + years","letter":"D"}]},"questions":[{"question":"Q002 - Which campus did you register to study with?","rows":[{"type":"base","values":{"Total":1363,"Online campus":561,"Cape Town":228,"Johannesburg":305,"Pretoria":194,"Durban":75,"1st yr":448,"2nd yr":316,"3rd yr":295,"4th yr":25,"Honours":253,"Masters":21,"18 - 20 years":248,"21 - 24 years":501,"25 - 34 years":251,"35 + years":332}},{"type":"category","label":"Online Access","freq":{"Total":88,"Online campus":88,"Cape Town":0,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":37,"2nd yr":18,"3rd yr":17,"4th yr":0,"Honours":11,"Masters":4,"18 - 20 years":4,"21 - 24 years":16,"25 - 34 years":18,"35 + years":49},"pct":{"Total":6,"Online campus":16,"Cape Town":0,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":8,"2nd yr":6,"3rd yr":6,"4th yr":0,"Honours":4,"Masters":19,"18 - 20 years":2,"21 - 24 years":3,"25 - 34 years":7,"35 + years":15},"sig":{"Online campus":"BCDE","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"A","35 + years":"ABC","Total":""}},{"type":"category","label":"Online","freq":{"Total":473,"Online campus":473,"Cape Town":0,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":146,"2nd yr":103,"3rd yr":110,"4th yr":0,"Honours":93,"Masters":17,"18 - 20 years":35,"21 - 24 years":121,"25 - 34 years":120,"35 + years":189},"pct":{"Total":35,"Online campus":84,"Cape Town":0,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":33,"2nd yr":33,"3rd yr":37,"4th yr":0,"Honours":37,"Masters":81,"18 - 20 years":14,"21 - 24 years":24,"25 - 34 years":48,"35 + years":57},"sig":{"Online campus":"BCDE","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"A","25 - 34 years":"AB","35 + years":"AB","Total":""}},{"type":"category","label":"Cape Town","freq":{"Total":228,"Online campus":0,"Cape Town":228,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":82,"2nd yr":54,"3rd yr":40,"4th yr":14,"Honours":38,"Masters":0,"18 - 20 years":51,"21 - 24 years":99,"25 - 34 years":37,"35 + years":33},"pct":{"Total":17,"Online campus":0,"Cape Town":100,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":18,"2nd yr":17,"3rd yr":14,"4th yr":56,"Honours":15,"Masters":0,"18 - 20 years":21,"21 - 24 years":20,"25 - 34 years":15,"35 + years":10},"sig":{"Online campus":"","Cape Town":"ACDE","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"D","21 - 24 years":"D","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Johannesburg","freq":{"Total":305,"Online campus":0,"Cape Town":0,"Johannesburg":305,"Pretoria":0,"Durban":0,"1st yr":102,"2nd yr":81,"3rd yr":68,"4th yr":10,"Honours":44,"Masters":0,"18 - 20 years":85,"21 - 24 years":127,"25 - 34 years":43,"35 + years":39},"pct":{"Total":22,"Online campus":0,"Cape Town":0,"Johannesburg":100,"Pretoria":0,"Durban":0,"1st yr":23,"2nd yr":26,"3rd yr":23,"4th yr":40,"Honours":17,"Masters":0,"18 - 20 years":34,"21 - 24 years":25,"25 - 34 years":17,"35 + years":12},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"ABDE","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"CD","21 - 24 years":"D","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Pretoria","freq":{"Total":194,"Online campus":0,"Cape Town":0,"Johannesburg":0,"Pretoria":194,"Durban":0,"1st yr":54,"2nd yr":49,"3rd yr":47,"4th yr":1,"Honours":43,"Masters":0,"18 - 20 years":50,"21 - 24 years":101,"25 - 34 years":24,"35 + years":16},"pct":{"Total":14,"Online campus":0,"Cape Town":0,"Johannesburg":0,"Pretoria":100,"Durban":0,"1st yr":12,"2nd yr":16,"3rd yr":16,"4th yr":4,"Honours":17,"Masters":0,"18 - 20 years":20,"21 - 24 years":20,"25 - 34 years":10,"35 + years":5},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"ABCE","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"CD","21 - 24 years":"CD","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Durban","freq":{"Total":75,"Online campus":0,"Cape Town":0,"Johannesburg":0,"Pretoria":0,"Durban":75,"1st yr":27,"2nd yr":11,"3rd yr":13,"4th yr":0,"Honours":24,"Masters":0,"18 - 20 years":23,"21 - 24 years":37,"25 - 34 years":9,"35 + years":6},"pct":{"Total":6,"Online campus":0,"Cape Town":0,"Johannesburg":0,"Pretoria":0,"Durban":100,"1st yr":6,"2nd yr":3,"3rd yr":4,"4th yr":0,"Honours":9,"Masters":0,"18 - 20 years":9,"21 - 24 years":7,"25 - 34 years":4,"35 + years":2},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"ABCD","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"B","Masters":"","18 - 20 years":"D","21 - 24 years":"D","25 - 34 years":"","35 + years":"","Total":""}}]},{"question":"Q003 - Which year did you start studying at SACAP?","rows":[{"type":"base","values":{"Total":1363,"Online campus":561,"Cape Town":228,"Johannesburg":305,"Pretoria":194,"Durban":75,"1st yr":448,"2nd yr":316,"3rd yr":295,"4th yr":25,"Honours":253,"Masters":21,"18 - 20 years":248,"21 - 24 years":501,"25 - 34 years":251,"35 + years":332}},{"type":"category","label":"2025","freq":{"Total":519,"Online campus":191,"Cape Town":96,"Johannesburg":121,"Pretoria":70,"Durban":41,"1st yr":390,"2nd yr":8,"3rd yr":2,"4th yr":0,"Honours":108,"Masters":9,"18 - 20 years":172,"21 - 24 years":152,"25 - 34 years":79,"35 + years":101},"pct":{"Total":38,"Online campus":34,"Cape Town":42,"Johannesburg":40,"Pretoria":36,"Durban":55,"1st yr":87,"2nd yr":3,"3rd yr":1,"4th yr":0,"Honours":43,"Masters":43,"18 - 20 years":69,"21 - 24 years":30,"25 - 34 years":31,"35 + years":30},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"A","1st yr":"BCE","2nd yr":"","3rd yr":"","4th yr":"","Honours":"BC","Masters":"","18 - 20 years":"BCD","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"2024","freq":{"Total":327,"Online campus":140,"Cape Town":55,"Johannesburg":71,"Pretoria":48,"Durban":13,"1st yr":42,"2nd yr":229,"3rd yr":2,"4th yr":0,"Honours":47,"Masters":5,"18 - 20 years":68,"21 - 24 years":111,"25 - 34 years":61,"35 + years":81},"pct":{"Total":24,"Online campus":25,"Cape Town":24,"Johannesburg":23,"Pretoria":25,"Durban":17,"1st yr":9,"2nd yr":72,"3rd yr":1,"4th yr":0,"Honours":19,"Masters":24,"18 - 20 years":27,"21 - 24 years":22,"25 - 34 years":24,"35 + years":24},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"C","2nd yr":"ACE","3rd yr":"","4th yr":"","Honours":"AC","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"2023","freq":{"Total":215,"Online campus":80,"Cape Town":37,"Johannesburg":46,"Pretoria":39,"Durban":13,"1st yr":8,"2nd yr":45,"3rd yr":159,"4th yr":0,"Honours":1,"Masters":2,"18 - 20 years":8,"21 - 24 years":124,"25 - 34 years":31,"35 + years":51},"pct":{"Total":16,"Online campus":14,"Cape Town":16,"Johannesburg":15,"Pretoria":20,"Durban":17,"1st yr":2,"2nd yr":14,"3rd yr":54,"4th yr":0,"Honours":0,"Masters":10,"18 - 20 years":3,"21 - 24 years":25,"25 - 34 years":12,"35 + years":15},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"AE","3rd yr":"ABE","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"ACD","25 - 34 years":"A","35 + years":"A","Total":""}},{"type":"category","label":"2022","freq":{"Total":150,"Online campus":66,"Cape Town":24,"Johannesburg":33,"Pretoria":23,"Durban":4,"1st yr":4,"2nd yr":26,"3rd yr":63,"4th yr":21,"Honours":35,"Masters":1,"18 - 20 years":0,"21 - 24 years":76,"25 - 34 years":35,"35 + years":38},"pct":{"Total":11,"Online campus":12,"Cape Town":11,"Johannesburg":11,"Pretoria":12,"Durban":5,"1st yr":1,"2nd yr":8,"3rd yr":21,"4th yr":84,"Honours":14,"Masters":5,"18 - 20 years":0,"21 - 24 years":15,"25 - 34 years":14,"35 + years":11},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"A","3rd yr":"AB","4th yr":"","Honours":"A","Masters":"","18 - 20 years":"","21 - 24 years":"A","25 - 34 years":"A","35 + years":"A","Total":""}},{"type":"category","label":"2021","freq":{"Total":86,"Online campus":45,"Cape Town":10,"Johannesburg":19,"Pretoria":10,"Durban":2,"1st yr":2,"2nd yr":5,"3rd yr":44,"4th yr":3,"Honours":32,"Masters":0,"18 - 20 years":0,"21 - 24 years":31,"25 - 34 years":18,"35 + years":32},"pct":{"Total":6,"Online campus":8,"Cape Town":4,"Johannesburg":6,"Pretoria":5,"Durban":3,"1st yr":0,"2nd yr":2,"3rd yr":15,"4th yr":12,"Honours":13,"Masters":0,"18 - 20 years":0,"21 - 24 years":6,"25 - 34 years":7,"35 + years":10},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"AB","4th yr":"","Honours":"AB","Masters":"","18 - 20 years":"","21 - 24 years":"A","25 - 34 years":"A","35 + years":"A","Total":""}},{"type":"category","label":"Prior to 2021","freq":{"Total":66,"Online campus":39,"Cape Town":6,"Johannesburg":15,"Pretoria":4,"Durban":2,"1st yr":2,"2nd yr":3,"3rd yr":25,"4th yr":1,"Honours":30,"Masters":4,"18 - 20 years":0,"21 - 24 years":7,"25 - 34 years":27,"35 + years":29},"pct":{"Total":5,"Online campus":7,"Cape Town":3,"Johannesburg":5,"Pretoria":2,"Durban":3,"1st yr":0,"2nd yr":1,"3rd yr":8,"4th yr":4,"Honours":12,"Masters":19,"18 - 20 years":0,"21 - 24 years":1,"25 - 34 years":11,"35 + years":9},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"AB","4th yr":"","Honours":"AB","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"AB","35 + years":"AB","Total":""}}]},{"question":"Q008 - How would you rate the support you received from the admissions team during your SACAP application process?","rows":[{"type":"base","values":{"Total":519,"Online campus":191,"Cape Town":96,"Johannesburg":121,"Pretoria":70,"Durban":41,"1st yr":390,"2nd yr":8,"3rd yr":2,"4th yr":0,"Honours":108,"Masters":9,"18 - 20 years":172,"21 - 24 years":152,"25 - 34 years":79,"35 + years":101}},{"type":"category","label":"Terrible","pct":{"Total":0,"Online campus":1,"Cape Town":0,"Johannesburg":1,"Pretoria":0,"Durban":0,"1st yr":1,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":0,"Masters":0,"18 - 20 years":0,"21 - 24 years":0,"25 - 34 years":1,"35 + years":1},"freq":{"Total":2,"Online campus":1,"Cape Town":0,"Johannesburg":1,"Pretoria":0,"Durban":0,"1st yr":2,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":0,"Masters":0,"18 - 20 years":0,"21 - 24 years":0,"25 - 34 years":1,"35 + years":1},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Not very good","pct":{"Total":3,"Online campus":3,"Cape Town":4,"Johannesburg":3,"Pretoria":3,"Durban":2,"1st yr":2,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":6,"Masters":11,"18 - 20 years":1,"21 - 24 years":4,"25 - 34 years":6,"35 + years":4},"freq":{"Total":17,"Online campus":6,"Cape Town":4,"Johannesburg":4,"Pretoria":2,"Durban":1,"1st yr":9,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":7,"Masters":1,"18 - 20 years":1,"21 - 24 years":6,"25 - 34 years":5,"35 + years":4},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"A","35 + years":"","Total":""}},{"type":"category","label":"About average","pct":{"Total":12,"Online campus":10,"Cape Town":16,"Johannesburg":13,"Pretoria":11,"Durban":10,"1st yr":12,"2nd yr":12,"3rd yr":50,"4th yr":0,"Honours":13,"Masters":0,"18 - 20 years":16,"21 - 24 years":9,"25 - 34 years":11,"35 + years":10},"freq":{"Total":63,"Online campus":20,"Cape Town":15,"Johannesburg":16,"Pretoria":8,"Durban":4,"1st yr":47,"2nd yr":1,"3rd yr":1,"4th yr":0,"Honours":14,"Masters":0,"18 - 20 years":28,"21 - 24 years":14,"25 - 34 years":9,"35 + years":10},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Good","pct":{"Total":37,"Online campus":30,"Cape Town":40,"Johannesburg":42,"Pretoria":46,"Durban":37,"1st yr":39,"2nd yr":25,"3rd yr":50,"4th yr":0,"Honours":31,"Masters":22,"18 - 20 years":41,"21 - 24 years":41,"25 - 34 years":39,"35 + years":27},"freq":{"Total":194,"Online campus":58,"Cape Town":38,"Johannesburg":51,"Pretoria":32,"Durban":15,"1st yr":154,"2nd yr":2,"3rd yr":1,"4th yr":0,"Honours":34,"Masters":2,"18 - 20 years":71,"21 - 24 years":62,"25 - 34 years":31,"35 + years":27},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Excellent","pct":{"Total":47,"Online campus":55,"Cape Town":41,"Johannesburg":40,"Pretoria":40,"Durban":51,"1st yr":45,"2nd yr":62,"3rd yr":0,"4th yr":0,"Honours":49,"Masters":67,"18 - 20 years":42,"21 - 24 years":45,"25 - 34 years":42,"35 + years":58},"freq":{"Total":242,"Online campus":105,"Cape Town":39,"Johannesburg":49,"Pretoria":28,"Durban":21,"1st yr":177,"2nd yr":5,"3rd yr":0,"4th yr":0,"Honours":53,"Masters":6,"18 - 20 years":72,"21 - 24 years":69,"25 - 34 years":33,"35 + years":59},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"A","Total":""}}]},{"question":"Q011 - How would you rate your experience with the re-registration process at SACAP?","rows":[{"type":"base","values":{"Total":837,"Online campus":360,"Cape Town":133,"Johannesburg":188,"Pretoria":122,"Durban":34,"1st yr":96,"2nd yr":296,"3rd yr":283,"4th yr":23,"Honours":127,"Masters":9,"18 - 20 years":88,"21 - 24 years":347,"25 - 34 years":154,"35 + years":230}},{"type":"category","label":"Terrible","pct":{"Total":4,"Online campus":2,"Cape Town":4,"Johannesburg":6,"Pretoria":11,"Durban":3,"1st yr":2,"2nd yr":5,"3rd yr":5,"4th yr":4,"Honours":3,"Masters":22,"18 - 20 years":5,"21 - 24 years":5,"25 - 34 years":3,"35 + years":4},"freq":{"Total":36,"Online campus":6,"Cape Town":5,"Johannesburg":11,"Pretoria":13,"Durban":1,"1st yr":2,"2nd yr":14,"3rd yr":13,"4th yr":1,"Honours":4,"Masters":2,"18 - 20 years":4,"21 - 24 years":16,"25 - 34 years":4,"35 + years":9},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"A","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Not very good","pct":{"Total":11,"Online campus":5,"Cape Town":21,"Johannesburg":15,"Pretoria":13,"Durban":6,"1st yr":10,"2nd yr":12,"3rd yr":12,"4th yr":4,"Honours":9,"Masters":0,"18 - 20 years":18,"21 - 24 years":13,"25 - 34 years":10,"35 + years":6},"freq":{"Total":93,"Online campus":18,"Cape Town":28,"Johannesburg":29,"Pretoria":16,"Durban":2,"1st yr":10,"2nd yr":36,"3rd yr":33,"4th yr":1,"Honours":12,"Masters":0,"18 - 20 years":16,"21 - 24 years":46,"25 - 34 years":16,"35 + years":14},"sig":{"Online campus":"","Cape Town":"A","Johannesburg":"A","Pretoria":"A","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"D","21 - 24 years":"D","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"About average","pct":{"Total":19,"Online campus":16,"Cape Town":23,"Johannesburg":22,"Pretoria":26,"Durban":9,"1st yr":19,"2nd yr":19,"3rd yr":21,"4th yr":13,"Honours":20,"Masters":22,"18 - 20 years":24,"21 - 24 years":22,"25 - 34 years":18,"35 + years":15},"freq":{"Total":163,"Online campus":57,"Cape Town":30,"Johannesburg":41,"Pretoria":32,"Durban":3,"1st yr":18,"2nd yr":56,"3rd yr":59,"4th yr":3,"Honours":25,"Masters":2,"18 - 20 years":21,"21 - 24 years":75,"25 - 34 years":28,"35 + years":35},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Good","pct":{"Total":34,"Online campus":37,"Cape Town":34,"Johannesburg":28,"Pretoria":30,"Durban":44,"1st yr":33,"2nd yr":38,"3rd yr":33,"4th yr":39,"Honours":26,"Masters":44,"18 - 20 years":33,"21 - 24 years":33,"25 - 34 years":36,"35 + years":34},"freq":{"Total":284,"Online campus":134,"Cape Town":45,"Johannesburg":53,"Pretoria":37,"Durban":15,"1st yr":32,"2nd yr":112,"3rd yr":93,"4th yr":9,"Honours":33,"Masters":4,"18 - 20 years":29,"21 - 24 years":113,"25 - 34 years":56,"35 + years":79},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"Excellent","pct":{"Total":31,"Online campus":40,"Cape Town":18,"Johannesburg":28,"Pretoria":20,"Durban":38,"1st yr":35,"2nd yr":26,"3rd yr":30,"4th yr":39,"Honours":41,"Masters":11,"18 - 20 years":19,"21 - 24 years":28,"25 - 34 years":32,"35 + years":40},"freq":{"Total":258,"Online campus":145,"Cape Town":24,"Johannesburg":52,"Pretoria":24,"Durban":13,"1st yr":34,"2nd yr":76,"3rd yr":85,"4th yr":9,"Honours":52,"Masters":1,"18 - 20 years":17,"21 - 24 years":97,"25 - 34 years":49,"35 + years":92},"sig":{"Online campus":"BCD","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"B","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"AB","Total":""}}]},{"question":"Q016 - How much do you trust SACAP to provide you with a good education?","rows":[{"type":"base","values":{"Total":1363,"Online campus":561,"Cape Town":228,"Johannesburg":305,"Pretoria":194,"Durban":75,"1st yr":448,"2nd yr":316,"3rd yr":295,"4th yr":25,"Honours":253,"Masters":21,"18 - 20 years":248,"21 - 24 years":501,"25 - 34 years":251,"35 + years":332}},{"type":"category","label":"0","pct":{"Total":0,"Online campus":0,"Cape Town":1,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":1,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":0,"Masters":0,"18 - 20 years":0,"21 - 24 years":0,"25 - 34 years":0,"35 + years":0},"freq":{"Total":3},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"1","pct":{"Total":0,"Online campus":0,"Cape Town":0,"Johannesburg":0,"Pretoria":0,"Durban":0,"1st yr":0,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":0,"Masters":0,"18 - 20 years":0,"21 - 24 years":0,"25 - 34 years":0,"35 + years":0},"freq":{"Total":2},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"2","pct":{"Total":0,"Online campus":0,"Cape Town":0,"Johannesburg":1,"Pretoria":1,"Durban":0,"1st yr":0,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":1,"Masters":0,"18 - 20 years":0,"21 - 24 years":1,"25 - 34 years":0,"35 + years":0},"freq":{"Total":5},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"3","pct":{"Total":0,"Online campus":1,"Cape Town":0,"Johannesburg":0,"Pretoria":1,"Durban":0,"1st yr":0,"2nd yr":0,"3rd yr":1,"4th yr":0,"Honours":1,"Masters":0,"18 - 20 years":0,"21 - 24 years":0,"25 - 34 years":1,"35 + years":1},"freq":{"Total":6},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"4","pct":{"Total":1,"Online campus":1,"Cape Town":1,"Johannesburg":1,"Pretoria":2,"Durban":1,"1st yr":2,"2nd yr":2,"3rd yr":1,"4th yr":0,"Honours":0,"Masters":0,"18 - 20 years":1,"21 - 24 years":1,"25 - 34 years":1,"35 + years":2},"freq":{"Total":15},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"5","pct":{"Total":3,"Online campus":3,"Cape Town":3,"Johannesburg":3,"Pretoria":2,"Durban":5,"1st yr":3,"2nd yr":3,"3rd yr":3,"4th yr":8,"Honours":4,"Masters":5,"18 - 20 years":2,"21 - 24 years":3,"25 - 34 years":4,"35 + years":3},"freq":{"Total":42},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"6","pct":{"Total":4,"Online campus":4,"Cape Town":7,"Johannesburg":3,"Pretoria":3,"Durban":5,"1st yr":4,"2nd yr":4,"3rd yr":3,"4th yr":4,"Honours":6,"Masters":0,"18 - 20 years":4,"21 - 24 years":4,"25 - 34 years":6,"35 + years":3},"freq":{"Total":59},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"7","pct":{"Total":10,"Online campus":10,"Cape Town":12,"Johannesburg":10,"Pretoria":6,"Durban":13,"1st yr":9,"2nd yr":8,"3rd yr":9,"4th yr":8,"Honours":13,"Masters":19,"18 - 20 years":11,"21 - 24 years":9,"25 - 34 years":10,"35 + years":11},"freq":{"Total":137},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"8","pct":{"Total":21,"Online campus":19,"Cape Town":29,"Johannesburg":19,"Pretoria":20,"Durban":24,"1st yr":17,"2nd yr":27,"3rd yr":19,"4th yr":24,"Honours":22,"Masters":19,"18 - 20 years":20,"21 - 24 years":23,"25 - 34 years":24,"35 + years":16},"freq":{"Total":286},"sig":{"Online campus":"","Cape Town":"A","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"A","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"9","pct":{"Total":20,"Online campus":19,"Cape Town":18,"Johannesburg":21,"Pretoria":21,"Durban":20,"1st yr":20,"2nd yr":18,"3rd yr":20,"4th yr":16,"Honours":21,"Masters":19,"18 - 20 years":23,"21 - 24 years":20,"25 - 34 years":16,"35 + years":21},"freq":{"Total":269},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"10","pct":{"Total":40,"Online campus":42,"Cape Town":28,"Johannesburg":43,"Pretoria":45,"Durban":31,"1st yr":42,"2nd yr":39,"3rd yr":44,"4th yr":40,"Honours":31,"Masters":38,"18 - 20 years":39,"21 - 24 years":39,"25 - 34 years":37,"35 + years":44},"freq":{"Total":539},"sig":{"Online campus":"B","Cape Town":"","Johannesburg":"B","Pretoria":"B","Durban":"","1st yr":"","2nd yr":"","3rd yr":"E","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"net","label":"Do not trust (0-4)","pct":{"Total":10,"Online campus":10,"Cape Town":14,"Johannesburg":7,"Pretoria":8,"Durban":12,"1st yr":11,"2nd yr":8,"3rd yr":8,"4th yr":12,"Honours":12,"Masters":5,"18 - 20 years":8,"21 - 24 years":10,"25 - 34 years":12,"35 + years":9},"sig":{}},{"type":"net","label":"Some trust (5-7)","pct":{"Total":31,"Online campus":29,"Cape Town":41,"Johannesburg":29,"Pretoria":26,"Durban":37,"1st yr":27,"2nd yr":35,"3rd yr":29,"4th yr":32,"Honours":36,"Masters":38,"18 - 20 years":31,"21 - 24 years":32,"25 - 34 years":35,"35 + years":26},"sig":{"Cape Town":"ACD"}},{"type":"net","label":"Fully trust (8-10)","pct":{"Total":59,"Online campus":61,"Cape Town":46,"Johannesburg":64,"Pretoria":66,"Durban":51,"1st yr":62,"2nd yr":57,"3rd yr":63,"4th yr":56,"Honours":52,"Masters":57,"18 - 20 years":62,"21 - 24 years":59,"25 - 34 years":53,"35 + years":65},"sig":{"Online campus":"B","Johannesburg":"B","Pretoria":"B","35 + years":"C"}},{"type":"net","label":"NPS (Fully trust - Do not trust)","pct":{"Total":50,"Online campus":51,"Cape Town":32,"Johannesburg":57,"Pretoria":59,"Durban":39,"1st yr":52,"2nd yr":49,"3rd yr":56,"4th yr":44,"Honours":40,"Masters":52,"18 - 20 years":54,"21 - 24 years":49,"25 - 34 years":41,"35 + years":56},"sig":{"Online campus":"B","Johannesburg":"B","Pretoria":"B"}}]},{"question":"Q017 - Would you recommend SACAP to others as a place to study?","rows":[{"type":"base","values":{"Total":1363,"Online campus":561,"Cape Town":228,"Johannesburg":305,"Pretoria":194,"Durban":75,"1st yr":448,"2nd yr":316,"3rd yr":295,"4th yr":25,"Honours":253,"Masters":21,"18 - 20 years":248,"21 - 24 years":501,"25 - 34 years":251,"35 + years":332}},{"type":"category","label":"0","pct":{"Total":2,"Online campus":1,"Cape Town":2,"Johannesburg":3,"Pretoria":2,"Durban":1,"1st yr":2,"2nd yr":2,"3rd yr":2,"4th yr":0,"Honours":1,"Masters":0,"18 - 20 years":0,"21 - 24 years":1,"25 - 34 years":3,"35 + years":2},"freq":{"Total":25},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"1","pct":{"Total":0,"Online campus":0,"Cape Town":0,"Johannesburg":0,"Pretoria":1,"Durban":0,"1st yr":1,"2nd yr":0,"3rd yr":0,"4th yr":0,"Honours":0,"Masters":0,"18 - 20 years":0,"21 - 24 years":0,"25 - 34 years":0,"35 + years":0},"freq":{"Total":4},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"2","pct":{"Total":1,"Online campus":1,"Cape Town":0,"Johannesburg":1,"Pretoria":2,"Durban":0,"1st yr":0,"2nd yr":1,"3rd yr":0,"4th yr":0,"Honours":1,"Masters":0,"18 - 20 years":0,"21 - 24 years":1,"25 - 34 years":1,"35 + years":1},"freq":{"Total":10},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"3","pct":{"Total":1,"Online campus":1,"Cape Town":2,"Johannesburg":0,"Pretoria":2,"Durban":3,"1st yr":1,"2nd yr":0,"3rd yr":1,"4th yr":4,"Honours":4,"Masters":5,"18 - 20 years":1,"21 - 24 years":1,"25 - 34 years":2,"35 + years":2},"freq":{"Total":19},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"B","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"4","pct":{"Total":2,"Online campus":2,"Cape Town":1,"Johannesburg":2,"Pretoria":1,"Durban":3,"1st yr":1,"2nd yr":2,"3rd yr":2,"4th yr":0,"Honours":2,"Masters":0,"18 - 20 years":0,"21 - 24 years":2,"25 - 34 years":2,"35 + years":2},"freq":{"Total":22},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"5","pct":{"Total":5,"Online campus":5,"Cape Town":7,"Johannesburg":3,"Pretoria":3,"Durban":4,"1st yr":4,"2nd yr":4,"3rd yr":5,"4th yr":12,"Honours":5,"Masters":10,"18 - 20 years":4,"21 - 24 years":6,"25 - 34 years":5,"35 + years":3},"freq":{"Total":63},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"6","pct":{"Total":5,"Online campus":4,"Cape Town":6,"Johannesburg":5,"Pretoria":8,"Durban":5,"1st yr":4,"2nd yr":5,"3rd yr":4,"4th yr":4,"Honours":9,"Masters":5,"18 - 20 years":5,"21 - 24 years":7,"25 - 34 years":5,"35 + years":3},"freq":{"Total":71},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"7","pct":{"Total":8,"Online campus":8,"Cape Town":6,"Johannesburg":8,"Pretoria":6,"Durban":12,"1st yr":7,"2nd yr":7,"3rd yr":7,"4th yr":4,"Honours":10,"Masters":10,"18 - 20 years":6,"21 - 24 years":6,"25 - 34 years":9,"35 + years":10},"freq":{"Total":103},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"8","pct":{"Total":16,"Online campus":15,"Cape Town":22,"Johannesburg":14,"Pretoria":11,"Durban":17,"1st yr":13,"2nd yr":21,"3rd yr":14,"4th yr":0,"Honours":17,"Masters":19,"18 - 20 years":16,"21 - 24 years":14,"25 - 34 years":16,"35 + years":17},"freq":{"Total":212},"sig":{"Online campus":"","Cape Town":"D","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"9","pct":{"Total":14,"Online campus":12,"Cape Town":17,"Johannesburg":15,"Pretoria":16,"Durban":8,"1st yr":14,"2nd yr":14,"3rd yr":13,"4th yr":24,"Honours":13,"Masters":14,"18 - 20 years":13,"21 - 24 years":15,"25 - 34 years":14,"35 + years":13},"freq":{"Total":187},"sig":{"Online campus":"","Cape Town":"","Johannesburg":"","Pretoria":"","Durban":"","1st yr":"","2nd yr":"","3rd yr":"","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"category","label":"10","pct":{"Total":47,"Online campus":50,"Cape Town":36,"Johannesburg":50,"Pretoria":50,"Durban":47,"1st yr":53,"2nd yr":45,"3rd yr":52,"4th yr":52,"Honours":37,"Masters":38,"18 - 20 years":54,"21 - 24 years":48,"25 - 34 years":44,"35 + years":47},"freq":{"Total":647},"sig":{"Online campus":"B","Cape Town":"","Johannesburg":"B","Pretoria":"B","Durban":"","1st yr":"E","2nd yr":"","3rd yr":"E","4th yr":"","Honours":"","Masters":"","18 - 20 years":"","21 - 24 years":"","25 - 34 years":"","35 + years":"","Total":""}},{"type":"net","label":"Detractor (0-6)","pct":{"Total":16,"Online campus":15,"Cape Town":19,"Johannesburg":13,"Pretoria":17,"Durban":16,"1st yr":13,"2nd yr":14,"3rd yr":15,"4th yr":20,"Honours":22,"Masters":19,"18 - 20 years":10,"21 - 24 years":17,"25 - 34 years":18,"35 + years":13},"sig":{"Honours":"A"}},{"type":"net","label":"Passive (7-8)","pct":{"Total":23,"Online campus":23,"Cape Town":28,"Johannesburg":22,"Pretoria":17,"Durban":29,"1st yr":20,"2nd yr":28,"3rd yr":21,"4th yr":4,"Honours":28,"Masters":29,"18 - 20 years":23,"21 - 24 years":20,"25 - 34 years":24,"35 + years":27},"sig":{}},{"type":"net","label":"Promoter (9-10)","pct":{"Total":61,"Online campus":62,"Cape Town":53,"Johannesburg":65,"Pretoria":66,"Durban":55,"1st yr":67,"2nd yr":58,"3rd yr":64,"4th yr":76,"Honours":50,"Masters":52,"18 - 20 years":67,"21 - 24 years":62,"25 - 34 years":57,"35 + years":60},"sig":{"1st yr":"E","3rd yr":"E"}},{"type":"net","label":"NPS (Promoter - Detractor)","pct":{"Total":45,"Online campus":47,"Cape Town":34,"Johannesburg":52,"Pretoria":49,"Durban":39,"1st yr":54,"2nd yr":44,"3rd yr":49,"4th yr":56,"Honours":28,"Masters":33,"18 - 20 years":56,"21 - 24 years":45,"25 - 34 years":39,"35 + years":48},"sig":{"1st yr":"E"}}]}]};

const BRAND = {
  navy: "#1a2744",
  teal: "#0d8a8a",
  tealLight: "#e6f5f5",
  coral: "#e8614d",
  gold: "#d4a843",
  slate: "#64748b",
  warmGray: "#f8f7f5",
  white: "#ffffff",
  text: "#1e293b",
  textLight: "#94a3b8",
  border: "#e2e8f0",
  sigUp: "#059669",
  sigDown: "#dc2626",
};

function getHeatColor(val, maxVal) {
  if (val === 0 || val === undefined || val === null) return "transparent";
  const intensity = Math.min(val / Math.max(maxVal, 1), 1);
  const r = Math.round(13 + (232 - 13) * (1 - intensity));
  const g = Math.round(138 + (241 - 138) * (1 - intensity));
  const b = Math.round(138 + (241 - 138) * (1 - intensity));
  return `rgba(${r}, ${g}, ${b}, ${0.15 + intensity * 0.45})`;
}

function SigBadge({ sig }) {
  if (!sig) return null;
  return (
    <span style={{
      display: "inline-block",
      fontSize: 9,
      fontWeight: 700,
      letterSpacing: "0.5px",
      color: BRAND.sigUp,
      background: "rgba(5, 150, 105, 0.08)",
      borderRadius: 3,
      padding: "1px 4px",
      marginLeft: 4,
      fontFamily: "'DM Mono', monospace",
      verticalAlign: "middle",
    }}>
      ▲{sig}
    </span>
  );
}

function LowBaseWarning({ n }) {
  if (n >= 30) return null;
  return (
    <span title={`Low base: n=${n}`} style={{
      display: "inline-block",
      fontSize: 8,
      color: BRAND.coral,
      fontWeight: 700,
      marginLeft: 2,
    }}>⚠</span>
  );
}

function CrosstabTable({ question, bannerGroup, showFreq, showHeatmap }) {
  const groups = DATA.banner_groups;
  const cols = groups[bannerGroup] || [];
  const colLabels = ["Total", ...cols.map(c => c.label)];
  const colLetters = ["—", ...cols.map(c => c.letter)];
  
  const baseRow = question.rows.find(r => r.type === "base");
  const categories = question.rows.filter(r => r.type === "category");
  const nets = question.rows.filter(r => r.type === "net");
  
  const maxPct = useMemo(() => {
    let max = 0;
    categories.forEach(cat => {
      colLabels.forEach(label => {
        const v = cat.pct?.[label] || 0;
        if (v > max && v < 100) max = v;
      });
    });
    return max;
  }, [categories, colLabels]);

  const cellStyle = (val, sig, isNet, baseN) => {
    const base = {
      padding: "8px 12px",
      textAlign: "right",
      fontSize: 13,
      fontFamily: "'DM Mono', monospace",
      position: "relative",
      borderBottom: `1px solid ${BRAND.border}`,
      transition: "background 0.15s ease",
    };
    if (isNet) {
      base.fontWeight = 700;
      base.color = BRAND.navy;
    }
    if (showHeatmap && !isNet && val > 0 && val < 100) {
      base.background = getHeatColor(val, maxPct);
    }
    if (sig) {
      base.color = BRAND.sigUp;
      base.fontWeight = 600;
    }
    if (baseN !== undefined && baseN < 30) {
      base.opacity = 0.45;
    }
    return base;
  };

  return (
    <div style={{ overflowX: "auto", borderRadius: 8, border: `1px solid ${BRAND.border}`, background: BRAND.white }}>
      <table style={{ width: "100%", borderCollapse: "collapse", minWidth: 600 }}>
        <thead>
          <tr style={{ background: BRAND.navy }}>
            <th style={{ padding: "10px 14px", textAlign: "left", color: BRAND.white, fontSize: 12, fontWeight: 600, letterSpacing: "0.3px", fontFamily: "'DM Sans', sans-serif", position: "sticky", left: 0, background: BRAND.navy, zIndex: 2, minWidth: 180 }}>
              Response
            </th>
            {colLabels.map((label, i) => (
              <th key={i} style={{ padding: "10px 12px", textAlign: "right", color: i === 0 ? BRAND.gold : "rgba(255,255,255,0.85)", fontSize: 11, fontWeight: 600, letterSpacing: "0.2px", fontFamily: "'DM Sans', sans-serif", whiteSpace: "nowrap" }}>
                <div>{label}</div>
                <div style={{ fontSize: 9, opacity: 0.6, marginTop: 2, fontFamily: "'DM Mono', monospace" }}>({colLetters[i]})</div>
              </th>
            ))}
          </tr>
          {/* Base row */}
          <tr style={{ background: "#f1f5f9" }}>
            <td style={{ padding: "6px 14px", fontSize: 11, fontWeight: 600, color: BRAND.slate, fontFamily: "'DM Sans', sans-serif", position: "sticky", left: 0, background: "#f1f5f9", zIndex: 1 }}>
              Base (n=)
            </td>
            {colLabels.map((label, i) => {
              const n = baseRow?.values?.[label] || 0;
              return (
                <td key={i} style={{ padding: "6px 12px", textAlign: "right", fontSize: 11, fontWeight: 600, color: n < 30 ? BRAND.coral : BRAND.slate, fontFamily: "'DM Mono', monospace", borderBottom: `2px solid ${BRAND.teal}` }}>
                  {n}<LowBaseWarning n={n} />
                </td>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {categories.map((cat, ri) => (
            <tr key={ri} style={{ cursor: "default" }}
              onMouseEnter={e => { e.currentTarget.style.background = "rgba(13,138,138,0.04)"; }}
              onMouseLeave={e => { e.currentTarget.style.background = "transparent"; }}
            >
              <td style={{ padding: "8px 14px", fontSize: 13, color: BRAND.text, fontFamily: "'DM Sans', sans-serif", borderBottom: `1px solid ${BRAND.border}`, position: "sticky", left: 0, background: BRAND.white, zIndex: 1, fontWeight: 500 }}>
                {cat.label}
              </td>
              {colLabels.map((label, ci) => {
                const pct = cat.pct?.[label];
                const freq = cat.freq?.[label];
                const sig = cat.sig?.[label];
                const baseN = baseRow?.values?.[label] || 0;
                return (
                  <td key={ci} style={cellStyle(pct, sig, false, baseN)}>
                    {showFreq ? (
                      <div>
                        <span>{pct !== undefined ? `${pct}%` : "—"}</span>
                        <div style={{ fontSize: 10, color: BRAND.textLight, marginTop: 1 }}>n={freq !== undefined ? freq : "—"}</div>
                      </div>
                    ) : (
                      <span>{pct !== undefined ? `${pct}%` : "—"}</span>
                    )}
                    {sig && <SigBadge sig={sig} />}
                  </td>
                );
              })}
            </tr>
          ))}
          {nets.length > 0 && (
            <>
              <tr><td colSpan={colLabels.length + 1} style={{ padding: 0, borderBottom: `2px solid ${BRAND.teal}` }} /></tr>
              {nets.map((net, ni) => {
                const isNPS = net.label.includes("NET POSITIVE") || net.label.includes("NPS");
                return (
                  <tr key={`net-${ni}`} style={{ background: isNPS ? "rgba(26,39,68,0.03)" : "rgba(248,247,245,0.5)" }}>
                    <td style={{ padding: "8px 14px", fontSize: 12, color: BRAND.navy, fontFamily: "'DM Sans', sans-serif", fontWeight: 700, borderBottom: `1px solid ${BRAND.border}`, position: "sticky", left: 0, background: isNPS ? "rgba(26,39,68,0.03)" : "rgba(248,247,245,0.8)", zIndex: 1 }}>
                      {isNPS ? "📊 " : ""}{net.label}
                    </td>
                    {colLabels.map((label, ci) => {
                      const pct = net.pct?.[label];
                      const sig = net.sig?.[label];
                      return (
                        <td key={ci} style={{
                          ...cellStyle(pct, sig, true, undefined),
                          background: isNPS ? "rgba(26,39,68,0.03)" : "transparent",
                          fontSize: 13,
                        }}>
                          {pct !== undefined ? `${pct}%` : "—"}
                          {sig && <SigBadge sig={sig} />}
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
            </>
          )}
        </tbody>
      </table>
    </div>
  );
}

export default function App() {
  const [selectedQ, setSelectedQ] = useState(0);
  const [bannerGroup, setBannerGroup] = useState("Campus");
  const [showFreq, setShowFreq] = useState(false);
  const [showHeatmap, setShowHeatmap] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  const questions = DATA.questions;
  const bannerGroups = Object.keys(DATA.banner_groups);
  
  const filteredQs = questions.filter(q =>
    q.question.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const currentQ = filteredQs[selectedQ] || questions[0];
  const qNum = currentQ.question.split(" - ")[0];
  const qText = currentQ.question.split(" - ").slice(1).join(" - ");

  return (
    <div style={{ fontFamily: "'DM Sans', sans-serif", background: BRAND.warmGray, minHeight: "100vh", color: BRAND.text }}>
      <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet" />
      
      {/* Header */}
      <div style={{ background: `linear-gradient(135deg, ${BRAND.navy} 0%, #2a3f5f 100%)`, padding: "24px 32px", borderBottom: `3px solid ${BRAND.teal}` }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", maxWidth: 1400, margin: "0 auto" }}>
          <div>
            <div style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, letterSpacing: "2px", textTransform: "uppercase", fontWeight: 600, marginBottom: 4 }}>
              The Research Lamppost · Turas Analytics
            </div>
            <h1 style={{ color: BRAND.white, fontSize: 22, fontWeight: 700, margin: 0, letterSpacing: "-0.3px" }}>
              SACAP Student Survey 2025
            </h1>
            <div style={{ color: "rgba(255,255,255,0.6)", fontSize: 12, marginTop: 4 }}>
              Interactive Crosstab Explorer · n=1,363 · 118 Questions · Significance at p&lt;0.05
            </div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div style={{ color: BRAND.gold, fontSize: 11, fontWeight: 600, letterSpacing: "1px" }}>PROTOTYPE</div>
            <div style={{ color: "rgba(255,255,255,0.4)", fontSize: 10, marginTop: 2 }}>Generated by Turas · reactable</div>
          </div>
        </div>
      </div>

      <div style={{ maxWidth: 1400, margin: "0 auto", padding: "20px 32px", display: "flex", gap: 24 }}>
        {/* Sidebar */}
        <div style={{ width: 280, flexShrink: 0 }}>
          <div style={{ position: "sticky", top: 20 }}>
            {/* Search */}
            <div style={{ marginBottom: 16 }}>
              <input
                type="text"
                placeholder="Search questions..."
                value={searchTerm}
                onChange={e => { setSearchTerm(e.target.value); setSelectedQ(0); }}
                style={{
                  width: "100%",
                  padding: "10px 14px",
                  border: `1px solid ${BRAND.border}`,
                  borderRadius: 6,
                  fontSize: 13,
                  fontFamily: "'DM Sans', sans-serif",
                  outline: "none",
                  background: BRAND.white,
                  boxSizing: "border-box",
                  transition: "border-color 0.15s",
                }}
                onFocus={e => e.target.style.borderColor = BRAND.teal}
                onBlur={e => e.target.style.borderColor = BRAND.border}
              />
            </div>

            {/* Question list */}
            <div style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, overflow: "hidden" }}>
              <div style={{ padding: "10px 14px", borderBottom: `1px solid ${BRAND.border}`, fontSize: 11, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase" }}>
                Questions ({filteredQs.length})
              </div>
              <div style={{ maxHeight: 500, overflowY: "auto" }}>
                {filteredQs.map((q, i) => {
                  const num = q.question.split(" - ")[0];
                  const text = q.question.split(" - ").slice(1).join(" - ");
                  const isActive = i === selectedQ;
                  return (
                    <div
                      key={i}
                      onClick={() => setSelectedQ(i)}
                      style={{
                        padding: "10px 14px",
                        cursor: "pointer",
                        borderBottom: `1px solid ${BRAND.border}`,
                        background: isActive ? BRAND.tealLight : "transparent",
                        borderLeft: isActive ? `3px solid ${BRAND.teal}` : "3px solid transparent",
                        transition: "all 0.12s ease",
                      }}
                      onMouseEnter={e => { if (!isActive) e.currentTarget.style.background = "#f8fafc"; }}
                      onMouseLeave={e => { if (!isActive) e.currentTarget.style.background = "transparent"; }}
                    >
                      <div style={{ fontSize: 10, fontWeight: 700, color: isActive ? BRAND.teal : BRAND.textLight, letterSpacing: "0.5px", marginBottom: 2 }}>
                        {num}
                      </div>
                      <div style={{ fontSize: 12, color: isActive ? BRAND.navy : BRAND.text, fontWeight: isActive ? 600 : 400, lineHeight: 1.35 }}>
                        {text.length > 80 ? text.slice(0, 80) + "..." : text}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Legend */}
            <div style={{ marginTop: 16, background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: 14 }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase", marginBottom: 10 }}>Legend</div>
              <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12 }}>
                  <SigBadge sig="AB" />
                  <span style={{ color: BRAND.text }}>Significantly higher than columns</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12 }}>
                  <span style={{ color: BRAND.coral, fontWeight: 700, fontSize: 11 }}>⚠ 28</span>
                  <span style={{ color: BRAND.text }}>Low base warning (n&lt;30)</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12 }}>
                  <div style={{ width: 20, height: 14, borderRadius: 3, background: getHeatColor(60, 80) }} />
                  <span style={{ color: BRAND.text }}>Heatmap intensity</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Main content */}
        <div style={{ flex: 1, minWidth: 0 }}>
          {/* Controls bar */}
          <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 16, flexWrap: "wrap" }}>
            {/* Banner group tabs */}
            <div style={{ display: "flex", gap: 0, background: BRAND.white, borderRadius: 6, border: `1px solid ${BRAND.border}`, overflow: "hidden" }}>
              {bannerGroups.map(grp => (
                <button
                  key={grp}
                  onClick={() => setBannerGroup(grp)}
                  style={{
                    padding: "8px 16px",
                    border: "none",
                    background: bannerGroup === grp ? BRAND.navy : "transparent",
                    color: bannerGroup === grp ? BRAND.white : BRAND.text,
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: "pointer",
                    fontFamily: "'DM Sans', sans-serif",
                    transition: "all 0.12s ease",
                    borderRight: `1px solid ${BRAND.border}`,
                  }}
                >
                  {grp}
                </button>
              ))}
            </div>

            <div style={{ flex: 1 }} />

            {/* Toggles */}
            <label style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, color: BRAND.slate, cursor: "pointer", userSelect: "none" }}>
              <input type="checkbox" checked={showHeatmap} onChange={e => setShowHeatmap(e.target.checked)} style={{ accentColor: BRAND.teal }} />
              Heatmap
            </label>
            <label style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, color: BRAND.slate, cursor: "pointer", userSelect: "none" }}>
              <input type="checkbox" checked={showFreq} onChange={e => setShowFreq(e.target.checked)} style={{ accentColor: BRAND.teal }} />
              Show n=
            </label>
          </div>

          {/* Question title */}
          <div style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: "16px 20px", marginBottom: 16 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
              <span style={{ fontSize: 13, fontWeight: 700, color: BRAND.teal, fontFamily: "'DM Mono', monospace", letterSpacing: "0.5px" }}>{qNum}</span>
              <h2 style={{ fontSize: 16, fontWeight: 600, color: BRAND.navy, margin: 0, lineHeight: 1.4 }}>{qText}</h2>
            </div>
            <div style={{ marginTop: 6, fontSize: 11, color: BRAND.textLight }}>
              Banner: <strong style={{ color: BRAND.teal }}>{bannerGroup}</strong> · {DATA.banner_groups[bannerGroup].length} columns · Showing column percentages
            </div>
          </div>

          {/* Table */}
          <CrosstabTable
            question={currentQ}
            bannerGroup={bannerGroup}
            showFreq={showFreq}
            showHeatmap={showHeatmap}
          />

          {/* Footer */}
          <div style={{ marginTop: 16, padding: "12px 16px", textAlign: "center", fontSize: 10, color: BRAND.textLight }}>
            Significance testing: Column proportions z-test with Bonferroni correction · p&lt;0.05 · Minimum base n=30
          </div>
        </div>
      </div>
    </div>
  );
}
