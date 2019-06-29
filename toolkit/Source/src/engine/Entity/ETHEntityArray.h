#ifndef ETH_ENTITY_ARRAY_H_
#define ETH_ENTITY_ARRAY_H_

#include "ETHEntity.h"
#include <vector>

class ETHEntityArray
{
public:
	ETHEntityArray();
	~ETHEntityArray();

	void AddRef();
	void Release();

	ETHEntityArray& operator=(const ETHEntityArray& other);
	void push_back(ETHEntityRawPtr p);
	unsigned int size() const;
	ETHEntityRawPtr& operator[] (const unsigned int index);
	const ETHEntityRawPtr& operator[] (const unsigned int index) const;

	ETHEntityRawPtr& operator[] (const unsigned long index);
	const ETHEntityRawPtr& operator[] (const unsigned long index) const;

	void clear();
	ETHEntityArray& operator+=(const ETHEntityArray& other);
	void unique();
	void removeDeadEntities();

private:
	std::vector<ETHEntityRawPtr> m_vector;
	int m_ref;
};

ETHEntityArray* ETHEntityArrayFactory();

#endif
